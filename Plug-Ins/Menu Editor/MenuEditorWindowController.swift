import Cocoa
import RFSupport


class MenuEditorWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = [
        "MENU",
        "cmnu",
        "CMNU"
    ]
    
    @IBOutlet weak var menuTable: NSTableView!
    let resource: Resource
    private let manager: RFEditorManager

    private var menuInfo = Menu()
    
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
        self.loadItems()
        self.updateView()
    }
        
    func reflectSelectedItem() {

    }
        
    /// Reload the views representing our ``items`` list.
    private func updateView() {
        menuTable.reloadData()
    }
    
    private func itemsFromData(_ data: Data) throws -> Menu {
        let commandsSize: CommandsSize
        if resource.typeCode == "cmnu" {
            commandsSize = .int16
        } else if resource.typeCode == "CMNU" {
            commandsSize = .int32
        } else {
            commandsSize = .none
        }

        var newMenu = Menu()
        let reader = BinaryDataReader(data)
        newMenu.menuID = try reader.read()
        try reader.advance(2)   // menu width
        try reader.advance(2)   // menu height
        newMenu.mdefID = try reader.read()
        try reader.advance(2)   // filler
        newMenu.enableFlags = try reader.read()
        newMenu.menuName = try reader.readPString()

        while reader.bytesRemaining > 5 {
            var newItem = MenuItem()
            newItem.itemName = try reader.readPString()
            let iconID: Int8 = try reader.read()
            newItem.iconID = (iconID == 0) ? 0 : Int(iconID) + 256
            let keyEquivalent: UInt8 = try reader.read()
            if keyEquivalent != 0 {
                newItem.keyEquivalent = String(data: Data([keyEquivalent]), encoding: .macOSRoman) ?? ""
            }
            let markCharacter: UInt8 = try reader.read()
            if markCharacter != 0 {
                newItem.markCharacter = String(data: Data([markCharacter]), encoding: .macOSRoman) ?? ""
            }
            newItem.styleByte = try reader.read()
            
            switch commandsSize {
            case .int16:
                let shortCommand: UInt16 = try reader.read()
                newItem.menuCommand = UInt32(shortCommand)
            case .int32:
                let longCommand: UInt32 = try reader.read()
                newItem.menuCommand = longCommand
            case .none:
                break // only breaks out of switch
            }

            newMenu.items.append(newItem)
        }
        try reader.advance(1)

        return newMenu
    }
    
    /// Parse the resource into our ``items`` list.
    private func loadItems() {
        if resource.data.isEmpty {
            createEmptyResource()
        }
        do {
            menuInfo = try itemsFromData(resource.data)
        } catch {
            menuInfo = Menu()
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
    
    private enum CommandsSize {
        case none
        case int16
        case int32
    }
    
    private func currentResourceStateAsData() throws -> Data {
        let writer = BinaryDataWriter()
        
        let commandsSize: CommandsSize
        if resource.typeCode == "cmnu" {
            commandsSize = .int16
        } else if resource.typeCode == "CMNU" {
            commandsSize = .int32
        } else {
            commandsSize = .none
        }
        
        writer.write(menuInfo.menuID)
        writer.write(Int16(0)) // width
        writer.write(Int16(0)) // height
        writer.write(menuInfo.mdefID) // mdef ID
        writer.write(Int16(0)) // filler
        writer.write(menuInfo.enableFlags) // enableFlags
        for item in menuInfo.items {
            try writer.writePString(item.itemName)
            writer.write((item.iconID == 0) ? Int8(0) : Int8(item.iconID - 256))
            let keyEquivalentBytes = [UInt8](item.keyEquivalent.data(using: .macOSRoman) ?? Data())
            writer.write(keyEquivalentBytes.first ?? UInt8(0))
            let markCharacterBytes = [UInt8](item.markCharacter.data(using: .macOSRoman) ?? Data())
            writer.write(markCharacterBytes.first ?? UInt8(0))
            writer.write(item.styleByte)
            
            switch commandsSize {
            case .int16:
                writer.write(UInt16(item.menuCommand))
            case .int32:
                writer.write(item.menuCommand)
            case .none:
                break // only breaks out of switch
            }
        }
        writer.write(UInt8(0)) // zero terminator
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
        createItem?.title = NSLocalizedString("Create New Item", comment: "menu command for adding menu items to MENUs")
    }
    
    func windowDidResignKey(_ notification: Notification) {
        let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
        createItem?.title = NSLocalizedString("Create New Resource…", comment: "")
    }
        
    @IBAction func createNewItem(_ sender: Any?) {
        var selRow = menuTable.selectedRow
        if selRow == -1 {
            selRow = menuInfo.items.count // No need to subtract 1, because title already offset the index by 1 compared to items.
        }
        menuInfo.items.insert(MenuItem(itemName: NSLocalizedString("New Item", comment: "name for new menu items")), at: selRow)
        
        updateView()
        menuTable.selectRowIndexes([selRow + 1], byExtendingSelection: false) // +1 to account for title row
        
        self.setDocumentEdited(true)
    }
    
    @IBAction func delete(_ sender: Any?) {
        do {
            let oldData = try currentResourceStateAsData()
            var deletedCount = 0
            
            for row in menuTable.selectedRowIndexes.reversed() {
                if row > 0 { // Don't allow deleting title.
                    menuInfo.items.remove(at: row - 1)
                    deletedCount += 1
                }
            }

            reflectSelectedItem()
            if deletedCount > 0 {
                self.window?.contentView?.undoManager?.beginUndoGrouping()
                self.window?.contentView?.undoManager?.setActionName((deletedCount > 0) ? NSLocalizedString("Delete Items", comment: "") : NSLocalizedString("Delete Item", comment: ""))
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
            
            do {
                menuInfo = try self.itemsFromData(data)
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
        
}

extension MenuEditorWindowController : NSTableViewDataSource, NSTableViewDelegate {
    
    static let titleColumn = NSUserInterfaceItemIdentifier("Name")
    static let shortcutColumn = NSUserInterfaceItemIdentifier("Shortcut")
    static let markColumn = NSUserInterfaceItemIdentifier("Mark")

    @MainActor func numberOfRows(in tableView: NSTableView) -> Int {
        return menuInfo.items.count + 1
    }

    @MainActor func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if row != 0 && menuInfo.items[row - 1].itemName.hasPrefix("-") {
            return ""
        }
        if tableColumn?.identifier == MenuEditorWindowController.titleColumn {
            if row != 0 {
                return menuInfo.items[row - 1].itemName
            } else {
                return menuInfo.menuName
            }
        } else if tableColumn?.identifier == MenuEditorWindowController.shortcutColumn {
            if row != 0 {
                return menuInfo.items[row - 1].keyEquivalent.isEmpty ? "" : "⌘ \(menuInfo.items[row - 1].keyEquivalent)"
            } else {
                return "" // Menu title has no shortcut.
            }
        } else if tableColumn?.identifier == MenuEditorWindowController.markColumn {
            if row != 0 {
                return menuInfo.items[row - 1].markCharacter
            } else {
                return "" // Menu title has no mark.
            }
        }
        
        return "?"
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = MenuItemTableRowView()
        if row == 0 {
            rowView.rowStyle = .titleCell
        } else if row == 1 && menuInfo.items.count == 1 {
            rowView.rowStyle = .onlyCell
        } else if row == 1 {
            rowView.rowStyle = .firstItemCell
        } else if menuInfo.items.count == row {
            rowView.rowStyle = .lastItemCell
        }
        if row > 0 && menuInfo.items[row - 1].itemName.hasPrefix("-") {
            rowView.contentStyle = .separator
        } else {
            rowView.contentStyle = .normal
        }
        return rowView
    }
    
    func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
        return tableColumn?.identifier == MenuEditorWindowController.titleColumn || row != 0
    }
    
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        let newValue = object as? String ?? ""
        if tableColumn?.identifier == MenuEditorWindowController.titleColumn {
            if row != 0 {
                menuInfo.items[row - 1].itemName = newValue
            } else {
                menuInfo.menuName = newValue
            }
        } else if tableColumn?.identifier == MenuEditorWindowController.shortcutColumn {
            if row != 0 {
                let prefixes = ["⌘ ", "⌘"]
                var newValueNoCommandKey = newValue
                for prefix in prefixes {
                    if newValueNoCommandKey.hasPrefix(prefix) {
                        newValueNoCommandKey = String(newValueNoCommandKey.dropFirst(prefix.count))
                    }
                }
                menuInfo.items[row - 1].keyEquivalent = newValueNoCommandKey
            }
        } else if tableColumn?.identifier == MenuEditorWindowController.markColumn {
            if row != 0 {
                menuInfo.items[row - 1].markCharacter = newValue
            }
        }
        
        self.setDocumentEdited(true)
    }
}
