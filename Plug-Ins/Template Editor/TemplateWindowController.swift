import Cocoa
import RKSupport

class TemplateWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuItemValidation, ResKnifeTemplatePlugin {
    let resource: Resource
    private let template: Resource
    private var resourceStructure: ElementList! = nil
    @IBOutlet var dataList: TabbableOutlineView!
    
    override var windowNibName: String {
        return "TemplateWindow"
    }
    
    required init(resource: Resource, template: Resource) {
        self.resource = resource
        self.template = template
        super.init(window: nil)
        
        self.load(data: resource.data)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.resourceDataDidChange(_:)), name: .ResourceDataDidChange, object: resource)
        NotificationCenter.default.addObserver(self, selector: #selector(self.templateDataDidChange(_:)), name: .ResourceDataDidChange, object: template)
        NotificationCenter.default.addObserver(self, selector: #selector(self.windowDidBecomeKey(_:)), name: NSWindow.didBecomeKeyNotification, object: self.window)
        NotificationCenter.default.addObserver(self, selector: #selector(self.windowDidResignKey(_:)), name: NSWindow.didResignKeyNotification, object: self.window)
    }

    required init(resource: Resource) {
        fatalError("init(resource:) has not been implemented")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func resourceDataDidChange(_ notification: NSNotification) {
        if !self.window!.isDocumentEdited {
            self.load(data: resource.data)
        }
    }
    
    @objc func templateDataDidChange(_ notification: NSNotification) {
        // Reload the template while keeping the current data
        self.load(data: resourceStructure.getResourceData())
        dataList.expandItem(nil, expandChildren: true)
    }
        
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle
        dataList.expandItem(nil, expandChildren: true)
    }
    
    func load(data: Data) {
        resourceStructure = ElementList(controller: self)
        do {
            try resourceStructure.readTemplate(data: template.data)
            try resourceStructure.readResource(data: data)
        } catch let error {
            print(error)
        }
        // expand all
        dataList?.reloadData()
        dataList?.expandItem(nil, expandChildren: true)
    }
    
    @IBAction func saveResource(_ sender: Any) {
        resource.data = resourceStructure.getResourceData()
        self.setDocumentEdited(false)
    }
    
    @IBAction func revertResource(_ sender: Any) {
        self.load(data: resource.data)
        self.setDocumentEdited(false)
    }
    
    // MARK: - OutlineView functions
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let item = item as! Element
        let view: NSView
        if let tableColumn = tableColumn {
            var identifier = tableColumn.identifier
            if identifier.rawValue == "data" {
                view = NSView(frame: NSMakeRect(0, 0, tableColumn.width, CGFloat(item.rowHeight)))
                item.configure(view: view)
            } else {
                // Use the focusable list label for elements that allow creating entries
                if let item = item as? ElementLSTB, item.allowsCreateListEntry() {
                    identifier = NSUserInterfaceItemIdentifier("listLabel")
                }
                view = outlineView.makeView(withIdentifier: identifier, owner: self)!
                let textField = (view as! NSTableCellView).textField!
                textField.stringValue = item.displayLabel
                textField.alignment = item is ElementLSTB ? .left : .right
            }
            view.toolTip = item.tooltip
        } else {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("groupView"), owner: self)!
            (item as! GroupElement).configureGroup(view: view as! NSTableCellView)
        }
        return view
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let item = item as? Element {
            return item.subElementCount
        }
        return Int(resourceStructure.count)
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item = item as? Element {
            return item.subElement(at: index)
        }
        return resourceStructure.element(at: index)
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return (item as! Element).hasSubElements
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return CGFloat((item as! Element).rowHeight)
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is GroupElement
    }
    
    // MARK: - Menu functions
    
    @IBAction func itemValueUpdated(_ sender: Any) {
        self.setDocumentEdited(true)
    }
    
    // these next five methods are a crude hack - the items ought to be in the responder chain themselves
    @IBAction func createNewItem(_ sender: Any) {
        // This works by selecting a list element (LSTB) and passing the message on to it
        let row = dataList.row(for: self.window!.firstResponder as! NSView)
        if let element = dataList.item(atRow: row) as? ElementLSTB, element.allowsCreateListEntry() {
            element.createListEntry()
            dataList.reloadData()
            let newHeader = dataList.view(atColumn: 0, row: row, makeIfNecessary: true)
            self.window?.makeFirstResponder(newHeader)
            self.setDocumentEdited(true)
            // Expand the item and scroll the new content into view
            dataList.expandItem(dataList.item(atRow: row), expandChildren: true)
            let lastChild = dataList.rowView(atRow: dataList.row(forItem: element), makeIfNecessary: true)
            lastChild?.scrollToVisible(lastChild!.bounds)
            newHeader?.scrollToVisible(newHeader!.superview!.bounds)
        }
    }
    
    @IBAction func delete(_ sender: Any) {
        let row = dataList.row(for: self.window!.firstResponder as! NSView)
        if let element = dataList.item(atRow: row) as? ElementLSTB, element.allowsRemoveListEntry() {
            element.removeListEntry()
            dataList.reloadData()
            let newHeader = dataList.view(atColumn: 0, row: row, makeIfNecessary: true)
            self.window?.makeFirstResponder(newHeader)
            self.setDocumentEdited(true)
        }
    }
    
    @IBAction func cut(_ sender: Any) {}
    @IBAction func copy(_ sender: Any) {}
    @IBAction func paste(_ sender: Any) {}
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let element = dataList.item(atRow: dataList.row(for: self.window!.firstResponder as! NSView))
        switch menuItem.action {
        case #selector(self.createNewItem(_:)):
            if let element = element as? ElementLSTB, element.allowsCreateListEntry() {
                return true
            }
            return false
        case #selector(self.delete(_:)):
            if let element = element as? ElementLSTB, element.allowsRemoveListEntry() {
                return true
            }
            return false
        case #selector(self.saveResource(_:)),
             #selector(self.revertResource(_:)):
            return self.window!.isDocumentEdited
        default:
            return false
        }
    }
    
    @objc func windowDidBecomeKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create List Entry", comment: "")
    }
    
    @objc func windowDidResignKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create New Resource…", comment: "")
    }
}
