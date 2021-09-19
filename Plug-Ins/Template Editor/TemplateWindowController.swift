import Cocoa
import RFSupport

class TemplateWindowController: AbstractEditor, TemplateEditor, NSOutlineViewDataSource, NSOutlineViewDelegate {
    static let supportedTypes: [String] = []
    
    let resource: Resource
    let manager: RFEditorManager
    let template: Resource
    private let filter: TemplateFilter.Type?
    private var resourceStructure: ElementList!
    private var validStructure = false
    @IBOutlet var dataList: TabbableOutlineView!
    var resourceCache: [String: [Resource]] = [:] // Shared cache for RSID/CASR
    
    override var windowNibName: String {
        return "TemplateWindow"
    }
    
    class func parseBasicTemplate(_ template: Resource, manager: RFEditorManager) throws -> [TemplateField] {
        return try TemplateParser(template: template, manager: manager, basic: true).parse()
    }
    
    required init?(resource: Resource, manager: RFEditorManager, template: Resource, filter: TemplateFilter.Type?) {
        self.resource = resource
        self.manager = manager
        self.template = template
        self.filter = filter
        super.init(window: nil)
        
        if !self.load(data: resource.data) {
            return nil
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.resourceDataDidChange(_:)), name: .ResourceDataDidChange, object: resource)
        NotificationCenter.default.addObserver(self, selector: #selector(self.templateDataDidChange(_:)), name: .ResourceDataDidChange, object: template)
    }

    required init(resource: Resource, manager: RFEditorManager) {
        fatalError("init(resource:manager:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func resourceDataDidChange(_ notification: NSNotification) {
        if self.window?.isDocumentEdited != true {
            _ = self.load(data: resource.data)
        }
    }
    
    @objc func templateDataDidChange(_ notification: NSNotification) {
        // Reload the template while keeping the current data
        _ = self.load(data: resourceStructure.getResourceData())
        dataList.expandItem(nil, expandChildren: true)
    }
        
    override func windowDidLoad() {
        self.window?.title = resource.defaultWindowTitle
        dataList.expandItem(nil, expandChildren: true)
        if validStructure && resource.data.isEmpty {
            self.setDocumentEdited(true)
        }
    }
    
    func load(data: Data) -> Bool {
        resourceStructure = ElementList(controller: self)
        if let filter = filter {
            resourceStructure.insert(ElementDVDR(type: "DVDR", label: "Filter Enabled: \(filter.name)"))
        }
        validStructure = resourceStructure.readTemplate(template)
        if validStructure && !resource.data.isEmpty {
            do {
                let data = try filter?.filter(data: resource.data, for: resource.typeCode) ?? resource.data
                let reader = BinaryDataReader(data)
                try resourceStructure.readData(from: reader)
                if reader.remainingBytes > 0 {
                    // Show warning
                    NSApp.presentError(TemplateError.truncate)
                }
            } catch BinaryDataReaderError.insufficientData {
                // Ignore error, data will be padded on save
            } catch let error {
                NSApp.presentError(error)
                return false
            }
        }
        // expand all
        dataList?.reloadData()
        dataList?.expandItem(nil, expandChildren: true)
        return true
    }
    
    // MARK: - Helper functions
    
    // This function is used by RSID/CASR to get resources for the combo box, caching them by type to improve performance.
    // Note that the cache is on the window controller instance rather than static, to ensure the resources aren't retained indefinitely.
    func resources(ofType type: String) -> [Resource] {
        if resourceCache[type] == nil {
            // Find resources in all documents, deduplicate and sort by name
            let allResources = manager.allResources(ofType: ResourceType(type, resource.typeAttributes), currentDocumentOnly: false)
            let resources: [Int: Resource] = allResources.reduce(into: [:]) { (result, resource) in
                if result[resource.id] == nil && !resource.name.isEmpty {
                    result[resource.id] = resource
                }
            }
            resourceCache[type] = resources.values.sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
        return resourceCache[type]!
    }
    
    func openOrCreateResource(typeCode: String, id: Int) {
        let type = ResourceType(typeCode, resource.typeAttributes)
        if let resource = manager.findResource(type: type, id: id, currentDocumentOnly: false) {
            manager.open(resource: resource)
        } else {
            manager.createResource(type: type, id: id, name: "")
        }
    }
    
    // MARK: - OutlineView functions
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let item = item as! Element
        let view: NSView
        if let tableColumn = tableColumn {
            var identifier = tableColumn.identifier
            if identifier.rawValue == "data" {
                view = DataView(frame: NSMakeRect(0, 2, tableColumn.width, CGFloat(item.rowHeight)))
                item.configure(view: view)
            } else {
                // Use the focusable list label for elements that allow creating entries
                if let item = item as? ElementLSTB, item.allowsCreateListEntry() {
                    identifier = NSUserInterfaceItemIdentifier(item.allowsRemoveListEntry() ? "listLabel" : "listEndLabel")
                }
                view = outlineView.makeView(withIdentifier: identifier, owner: self)!
                let textField = (view as! NSTableCellView).textField!
                textField.stringValue = item.displayLabel
                textField.alignment = item is ElementLSTB ? .left : .right
                textField.allowsDefaultTighteningForTruncation = true
            }
            view.toolTip = item.tooltip
        } else {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("groupView"), owner: self)!
            (item as! GroupElement).configureGroup(view: view as! NSTableCellView)
            if item is CounterElement {
                // Match indentation of list headers with that in TabbableOutlineView
                let indent = outlineView.level(forItem: item) * 16
                let constraint = view.constraints.first(where: { $0.firstAttribute == .leading })!
                constraint.constant = 5 + CGFloat(indent)
            }
        }
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? CollectionElement {
            return item.subElementCount
        }
        return Int(resourceStructure.count)
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? CollectionElement {
            return item.subElement(at: index)
        }
        return resourceStructure.element(at: index)
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is CollectionElement
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return CGFloat((item as! Element).rowHeight) + 4
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is GroupElement
    }
    
    // MARK: - Menu functions
    
    @IBAction func saveResource(_ sender: Any) {
        if self.window?.makeFirstResponder(dataList) != false {
            do {
                let data = resourceStructure.getResourceData()
                resource.data = try filter?.unfilter(data: data, for: resource.typeCode) ?? data
                self.setDocumentEdited(false)
            } catch let error {
                NSApp.presentError(error)
            }
        }
    }
    
    @IBAction func revertResource(_ sender: Any) {
        _ = self.load(data: resource.data)
        self.setDocumentEdited(false)
    }
    
    @IBAction func itemValueUpdated(_ sender: Any) {
        self.setDocumentEdited(true)
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create List Entry", comment: "")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create New Resource…", comment: "")
    }
}
