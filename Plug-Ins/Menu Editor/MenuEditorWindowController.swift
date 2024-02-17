import Cocoa
import RFSupport


class MenuEditorWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = [
        "MENU",
    ]
    
    let resource: Resource
    private let manager: RFEditorManager
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var titleContentsField: NSTextField!
    @IBOutlet weak var enabledCheckbox: NSButton!
    var menuID: Int16 = 128
    var mdefID: Int16 = 0
    var enableFlags: UInt32 = UInt32.max
    var menuName = "New Menu"

    private var items = [MenuItem]()
    
    override var windowNibName: String {
        return "MenuEditorWindow"
    }
    
    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(itemDoubleClicked(_:)), name: MenuDocumentView.itemDoubleClickedNotification, object: self.scrollView.documentView)
        NotificationCenter.default.addObserver(self, selector: #selector(itemFrameDidChange(_:)), name: MenuDocumentView.itemFrameDidChangeNotification, object: self.scrollView.documentView)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedItemDidChange(_:)), name: MenuDocumentView.selectionDidChangeNotification, object: self.scrollView.documentView)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedItemWillChange(_:)), name: MenuDocumentView.selectionWillChangeNotification, object: self.scrollView.documentView)
        self.loadItems()
        self.updateView()
    }
    
    @objc func itemDoubleClicked(_ notification: Notification) {
        // If we had a hideable inspector, this is where we'd show it.
    }
    
    @objc func itemFrameDidChange(_ notification: Notification) {
        self.setDocumentEdited(true)
    }
    
    func reflectSelectedItem() {
        for item in items {
            if item.itemView.selected {
                enabledCheckbox.isEnabled = true
                return
            }
        }
        enabledCheckbox.isEnabled = false
    }
    
    @objc func selectedItemWillChange(_ notification: Notification) {
        window?.makeFirstResponder(scrollView.documentView)
    }
    
    @objc func selectedItemDidChange(_ notification: Notification) {
        reflectSelectedItem()
    }
    
    /// Reload the views representing our ``items`` list.
    private func updateView() {
        for view in self.scrollView.documentView?.subviews ?? [] {
            view.removeFromSuperview()
        }
        var maxSize = NSSize(width: 128, height: 64)
        for item in items {
            self.scrollView.documentView?.addSubview(item.itemView)
            let itemBox = item.itemView.frame
            maxSize.width = max(itemBox.maxX, maxSize.width)
            maxSize.height = max(itemBox.maxY, maxSize.height)
        }
        var documentBox = self.scrollView.documentView?.frame ?? NSZeroRect
        documentBox.size.width = max(documentBox.size.width, maxSize.width + 16)
        documentBox.size.height = max(documentBox.size.height, maxSize.height + 16)
        self.scrollView.documentView?.frame = documentBox
#if compiler(>=5.9)
        // On macOS 14+ this defaults to false.
        self.scrollView.documentView?.clipsToBounds = true
#endif
    }
    
    private func itemsFromData(_ data: Data) throws -> [MenuItem] {
        let reader = BinaryDataReader(data)
        let menuID: Int16 = try reader.read()
        try reader.advance(2)   // menu width
        try reader.advance(2)   // menu height
        let mdefID: Int16 = try reader.read()
        try reader.advance(2)   // filler
        let enableFlags: UInt32 = try reader.read()
        let menuName = try reader.readPString()
        var newItems = [MenuItem]()
        var itemBox = NSRect(x: 0, y: 0, width: 300, height: 22)

        while reader.bytesRemaining > 5 {
            let itemName = try reader.readPString()
            let iconID: Int8 = try reader.read()
            let keyEquivalent: UInt8 = try reader.read()
            let markCharacter: UInt8 = try reader.read()
            let styleByte: UInt8 = try reader.read()
            
            let view = MenuItemView(frame: itemBox, title: itemName, enabled: , manager: <#T##RFEditorManager#>)
            let item = MenuItem(itemView: <#T##MenuItemView#>, enabled: <#T##Bool#>, title: <#T##String#>, iconID: <#T##Int#>, keyEquivalent: <#T##String#>, markCharacter: <#T##String#>, style: <#T##UInt8#>)
            newItems.append(item)
            
            itemBox = itemBox.offsetBy(dx: 0, dy: itemBox.size.height)
        }
        try reader.advance(1)

        return newItems
    }
    
    /// Parse the resource into our ``items`` list.
    private func loadItems() {
        if resource.data.isEmpty {
            createEmptyResource()
        }
        do {
            items = try itemsFromData(resource.data)
        } catch {
            items = []
            self.window?.presentError(error)
        }
    }
    
    /// Create a valid but empty Menu resource. Used when we are opened for an empty resource.
    private func createEmptyResource() {
        let writer = BinaryDataWriter()
        writer.write(Int16(resource.id))
        writer.write(Int16(0)) // width
        writer.write(Int16(0)) // height
        writer.write(Int16(0)) // mdef ID
        writer.write(Int16(0)) // filler
        writer.write(UInt32.max) // enableFlags
        try! writer.writePString("New Menu") // menu title
        writer.write(UInt8(0)) // zero terminator
        resource.data = writer.data
        
        self.setDocumentEdited(true)
    }
    
    private func currentResourceStateAsData() throws -> Data {
        let writer = BinaryDataWriter()
        
        
        for item in items {
            try item.write(to: writer)
        }
        return writer.data
    }
    
    /// Write the current state of the ``items`` list back to the resource.
    @IBAction func saveResource(_ sender: Any) {
        do {
            resource.data = try currentResourceStateAsData()
        } catch {
            self.window?.presentError(error)
        }
        
        self.setDocumentEdited(false)
    }
    
    /// Revert the resource to its on-disk state.
    @IBAction func revertResource(_ sender: Any) {
        self.window?.contentView?.undoManager?.removeAllActions()
        self.loadItems()
        self.updateView()
        
        self.setDocumentEdited(false)
    }
    
    
    func windowDidBecomeKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create New Item", comment: "")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create New Resource…", comment: "")
    }
    
    @IBAction func deselectAll(_ sender: Any?) {
        NotificationCenter.default.post(name: MenuDocumentView.selectionWillChangeNotification, object: scrollView.documentView)
        for itemView in scrollView.documentView?.subviews ?? [] {
            if let itemView = itemView as? MenuItemView,
               itemView.selected {
                itemView.selected = false
                itemView.needsDisplay = true
            }
        }
        NotificationCenter.default.post(name: MenuDocumentView.selectionDidChangeNotification, object: scrollView.documentView)
    }
    
    override func selectAll(_ sender: Any?) {
        NotificationCenter.default.post(name: MenuDocumentView.selectionWillChangeNotification, object: scrollView.documentView)
        for itemView in scrollView.documentView?.subviews ?? [] {
            if let itemView = itemView as? MenuItemView,
               !itemView.selected {
                itemView.selected = true
                itemView.needsDisplay = true
            }
        }
        NotificationCenter.default.post(name: MenuDocumentView.selectionDidChangeNotification, object: scrollView.documentView)
    }
    
    @IBAction func createNewItem(_ sender: Any?) {
        deselectAll(nil)
        let view = MenuItemView(frame: NSRect(origin: NSPoint(x: 10, y: 10), size: NSSize(width: 80, height: 20)), title: "Button", type: .button, enabled: true, resourceID: 0, manager: manager)
        NotificationCenter.default.post(name: MenuDocumentView.selectionWillChangeNotification, object: scrollView.documentView)
        view.selected = true
        let newItem = MenuItem(itemView: view, enabled: true, itemType: .button, resourceID: 0, helpItemType: .unknown, itemNumber: 0)
        items.append(newItem)
        self.scrollView.documentView?.addSubview(view)
        NotificationCenter.default.post(name: MenuDocumentView.selectionDidChangeNotification, object: scrollView.documentView)
        self.setDocumentEdited(true)
    }
    
    @IBAction func delete(_ sender: Any?) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            for itemIndex in (0 ..< items.count).reversed() {
                let itemView = items[itemIndex].itemView
                if itemView.selected {
                    itemView.removeFromSuperview()
                    items.remove(at: itemIndex)
                    didChange = true
                }
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Delete Item", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    private func undoRedoResourceData(_ data: Data) {
        do {
            let oldData = try currentResourceStateAsData()
            self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
            
            for item in items {
                item.itemView.removeFromSuperview()
            }
            
            do {
                items = try self.itemsFromData(data)
                self.updateView()
                self.reflectSelectedItem()
                
                self.setDocumentEdited(true)
            } catch {
                self.window?.presentError(error)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func typePopupSelectionDidChange(_ sender: NSPopUpButton) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newType = MenuItem.MenuItemType(rawValue: UInt8(sender.selectedTag())) ?? .unknown
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    items[itemIndex].itemType = newType
                    itemView.type = newType
                    itemView.needsDisplay = true
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Type", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func resourceIDFieldChanged(_ sender: Any) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newID = resourceIDField.integerValue
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    items[itemIndex].resourceID = newID
                    itemView.resourceID = newID
                    itemView.needsDisplay = true
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Resource ID", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func helpResourceIDFieldChanged(_ sender: Any) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newID = helpResourceIDField.integerValue
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    items[itemIndex].resourceID = newID
                    itemView.resourceID = newID
                    itemView.needsDisplay = true
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Resource ID", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func helpTypePopupSelectionDidChange(_ sender: NSPopUpButton) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newType = MenuItem.MenuHelpItemType(rawValue: UInt16(sender.selectedTag())) ?? .unknown
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    items[itemIndex].helpItemType = newType
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Help Type", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func helpItemFieldChanged(_ sender: Any) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newID = Int16(helpItemField.integerValue)
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    items[itemIndex].itemNumber = newID
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Help Item Index", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func enabledCheckBoxChanged(_ sender: Any) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newState = enabledCheckbox.state == .on
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    items[itemIndex].enabled = newState
                    itemView.enabled = newState
                    itemView.needsDisplay = true
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Enable State", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
    @IBAction func titleContentsFieldChanged(_ sender: Any) {
        do {
            let oldData = try currentResourceStateAsData()
            
            var didChange = false
            var itemIndex = 0
            let newTitle = titleContentsField.stringValue
            for item in items {
                let itemView = item.itemView
                if itemView.selected {
                    itemView.title = newTitle
                    itemView.needsDisplay = true
                    didChange = true
                }
                itemIndex += 1
            }
            reflectSelectedItem()
            if didChange {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Text", comment: ""))
                self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
                self.window?.contentView?.undoManager?.endUndoGrouping()
                
                self.setDocumentEdited(true)
            }
        } catch {
            self.window?.presentError(error)
        }
    }
    
}
