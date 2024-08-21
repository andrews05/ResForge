import AppKit
import RFSupport

enum TemplateEdited {
    case none
    case user
    case forced
}

class TemplateEditor: AbstractEditor, ResourceEditor {
    static let supportedTypes: [String] = []

    let resource: Resource
    let manager: RFEditorManager
    let template: Resource
    private let filter: TemplateFilter.Type?
    private var elementList: ElementList!
    private var validStructure = false
    @IBOutlet var dataList: TabbableOutlineView!
    var resourceCache: [String: [Resource]] = [:] // Shared cache for RSID/CASR
    private var edited = TemplateEdited.none {
        didSet {
            self.setDocumentEdited(edited != .none)
        }
    }

    override var windowNibName: String {
        return "TemplateWindow"
    }

    required init?(resource: Resource, manager: RFEditorManager, template: Resource, filter: TemplateFilter.Type?) {
        self.resource = resource
        self.manager = manager
        self.template = template
        self.filter = filter
        super.init(window: nil)

        // Add observer before possible failure as deinit will still run regardless
        UserDefaults.standard.addObserver(self, forKeyPath: RFDefaults.resourceNameInTemplate, context: nil)

        if !self.load(data: resource.data) {
            return nil
        }

        NotificationCenter.default.addObserver(self, selector: #selector(self.resourceDataDidChange(_:)), name: .ResourceDataDidChange, object: resource)
        NotificationCenter.default.addObserver(self, selector: #selector(self.templateDataDidChange(_:)), name: .ResourceDataDidChange, object: template)
    }

    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: RFDefaults.resourceNameInTemplate)
    }

    required init(resource: Resource, manager: RFEditorManager) {
        fatalError("init(resource:manager:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func resourceDataDidChange(_ notification: NSNotification) {
        if edited != .user {
            self.load(data: resource.data, reloadTemplate: false)
        }
    }

    @objc func templateDataDidChange(_ notification: NSNotification) {
        // Reload the template while keeping the current data
        self.load(data: self.getData())
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // UserDefaults for resourceNameInTemplate changed - reload the structure
        self.load(data: self.getData())
    }

    override func windowDidLoad() {
        dataList.expandItem(nil, expandChildren: true)
        self.setDocumentEdited(edited != .none)
    }

    @discardableResult func load(data: Data, reloadTemplate: Bool = true) -> Bool {
        edited = .none
        if reloadTemplate || elementList == nil {
            elementList = ElementList(controller: self)
            validStructure = elementList.readTemplate(template, filterName: filter?.name)
        }
        if validStructure {
            do {
                let data = try filter?.filter(data: data, for: resource.typeCode) ?? data
                let reader = BinaryDataReader(data)
                try elementList.readData(from: reader)
                if reader.bytesRemaining > 0 {
                    // Show warning
                    NSApp.presentError(TemplateError.truncate)
                }
            } catch BinaryDataReaderError.insufficientData {
                // Ignore error, data will be padded on save
                edited = .forced
            } catch let error {
                NSApp.presentError(error)
                return false
            }
        }
        // Expand all
        dataList?.reloadData()
        dataList?.expandItem(nil, expandChildren: true)
        return true
    }

    func getData() -> Data {
        let data = elementList.getData()
        return filter?.unfilter(data: data, for: resource.typeCode) ?? data
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
                let order = $0.name.localizedStandardCompare($1.name)
                return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
            }
        }
        return resourceCache[type]!
    }

    func openOrCreateResource(typeCode: String, id: Int, callback: ((Resource, Bool) -> Void)? = nil) {
        let type = ResourceType(typeCode, resource.typeAttributes)
        if let resource = manager.findResource(type: type, id: id, currentDocumentOnly: false) {
            manager.open(resource: resource)
            callback?(resource, false)
        } else {
            manager.createResource(type: type, id: id) { [weak self] resource in
                guard let self else { return }
                // Reset the cache for this type
                if resourceCache[resource.typeCode] != nil && !resource.name.isEmpty {
                    resourceCache.removeValue(forKey: resource.typeCode)
                }
                callback?(resource, true)
            }
        }
    }

    // MARK: - Menu functions

    @IBAction func saveResource(_ sender: Any) {
        if self.window?.makeFirstResponder(dataList) != false {
            resource.data = self.getData()
            edited = .none
        }
    }

    @IBAction func revertResource(_ sender: Any) {
        self.load(data: resource.data)
        edited = .none
    }

    @IBAction func itemValueUpdated(_ sender: Any) {
        edited = .user
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

extension TemplateEditor: NSOutlineViewDelegate, NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let item = item as! BaseElement
        let view: NSView
        if let tableColumn {
            var identifier = tableColumn.identifier
            if identifier.rawValue == "data" {
                view = TemplateDataView(frame: NSRect(x: 0, y: 2, width: tableColumn.width, height: CGFloat(item.rowHeight)))
                item.configure(view: view)
                if !item.subtext.isEmpty {
                    let subtext = NSTextField(labelWithString: item.subtext)
                    subtext.font = .systemFont(ofSize: 12)
                    subtext.textColor = .secondaryLabelColor
                    subtext.setFrameOrigin(NSPoint(x: item.width - 2, y: 6))
                    view.addSubview(subtext)
                }
            } else {
                var alignment = NSTextAlignment.right
                if let item = item as? ElementLSTB {
                    if item.allowsCreateListEntry() {
                        // Use the focusable list label for elements that allow creating entries
                        identifier = NSUserInterfaceItemIdentifier(item.allowsRemoveListEntry() ? "listLabel" : "listEndLabel")
                        alignment = .left
                    } else if item.singleElement == nil {
                        // Fixed count list labels should also be aligned left
                        alignment = .left
                    }
                }
                view = outlineView.makeView(withIdentifier: identifier, owner: self)!
                let textField = (view as! NSTableCellView).textField!
                textField.stringValue = item.displayLabel
                textField.alignment = alignment
                textField.allowsDefaultTighteningForTruncation = true
            }
        } else {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("groupView"), owner: self)!
            let cell = view as! NSTableCellView
            (item as! GroupElement).configureGroup(view: cell)
            if item is CounterElement {
                // Match indentation of list headers with that in TabbableOutlineView
                let indent = outlineView.level(forItem: item) * 16
                let constraint = view.constraints.first(where: { $0.firstAttribute == .leading })!
                constraint.constant = 5 + CGFloat(indent)
            }
        }
        return view
    }

    // This seemingly redundant function works around a bug in macOS 13 that causes problems with the key-view loop
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        return NSTableRowView()
    }

    func outlineView(_ outlineView: NSOutlineView, didAdd rowView: NSTableRowView, forRow row: Int) {
        // RNAM field should be visually distinct
        guard outlineView.item(atRow: row) is ElementRNAM else {
            return
        }
        rowView.backgroundColor = .controlAccentColor.withAlphaComponent(0.15)
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? CollectionElement {
            return item.subElementCount
        }
        return Int(elementList.count)
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? CollectionElement {
            return item.subElement(at: index)
        }
        return elementList.element(at: index)
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is CollectionElement
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return CGFloat((item as! BaseElement).rowHeight) + 4
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is GroupElement
    }
}
