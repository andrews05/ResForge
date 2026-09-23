import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/MacintoshToolboxEssentials.pdf#page=327
// https://dev.os9.ca/techpubs/mac/MacAppProgGuide/MacAppProgGuide-86.html#MARKER-2-35

public class MenuEditor: AbstractEditor, ResourceEditor {
    enum CommandSize {
        case none
        case int16
        case int32
    }

    public static var bundle: Bundle { .module }
    public static let supportedTypes = [
        "MENU",
        "cmnu",
        "CMNU"
    ]

    public static func register() {
        ValueTransformer.setValueTransformer(CharCodeTransformer(), forName: .charCodeTransformerName)
        PluginRegistry.register(Self.self)
    }

    public let resource: Resource
    public let createMenuTitle: String? = "Add Menu Item"
    let manager: RFEditorManager

    @IBOutlet weak var menuTable: NSTableView!
    private var menuInfo: Menu!

    public override var windowNibName: NSNib.Name {
        "MenuEditorWindow"
    }

    required public init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        super.init(window: nil)
        menuInfo = Menu(editor: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func windowDidLoad() {
        self.loadItems()
        menuTable.reloadData()
    }

    /// For inspector UI to bind to.
    @objc dynamic var selectedItem: Any?
    @objc dynamic var selectedMenu: Menu?
    @objc dynamic var selectedMenuItem: MenuItem?

    var commandSize: CommandSize {
        switch resource.typeCode {
        case "cmnu": .int16
        case "CMNU": .int32
        default: .none
        }
    }

    func updateRow(for item: MenuItem) {
        if let itemIndex = menuInfo.items.firstIndex(of: item),
           let itemRowView = menuTable.rowView(atRow: itemIndex + 1, makeIfNecessary: false) as? MenuItemTableRowView {
            if item.name.hasPrefix("-") {
                itemRowView.contentStyle = .separator
            } else if item.hasSubmenu {
                itemRowView.contentStyle = .submenu
            } else {
                itemRowView.contentStyle = .normal
            }
        }
    }

    private func itemsFromData(_ data: Data) throws {
        let reader = BinaryDataReader(data)
        menuInfo.menuID = try reader.read()
        try reader.advance(2)   // menu width
        try reader.advance(2)   // menu height
        menuInfo.mdefID = try reader.read()
        try reader.advance(2)   // filler
        menuInfo.enableFlags = try reader.read()
        menuInfo.name = try reader.readPString()

        while reader.bytesRemaining > 5 {
            let newItem = MenuItem(editor: self)
            newItem.name = try reader.readPString()
            newItem.iconCode = try reader.read()
            newItem.keyCode = try reader.read()
            newItem.markCode = try reader.read()
            newItem.style = try reader.read()
            newItem.isEnabled = menuInfo.isEnabled(at: menuInfo.items.count)

            switch commandSize {
            case .int16:
                if (reader.bytesRead % 2) != 0 {
                    try reader.advance(1)
                }
                newItem.menuCommand = UInt32(try reader.read() as UInt16)
            case .int32:
                if (reader.bytesRead % 2) != 0 {
                    try reader.advance(1)
                }
                newItem.menuCommand = try reader.read()
            case .none:
                break
            }

            menuInfo.items.append(newItem)
        }
        try reader.advance(1)
    }

    /// Parse the resource into our ``items`` list.
    private func loadItems() {
        menuInfo = Menu(editor: self)
        if resource.data.isEmpty {
            self.setDocumentEdited(true)
        } else {
            do {
                try itemsFromData(resource.data)
            } catch {
                self.window?.presentError(error)
            }
            self.setDocumentEdited(false)
        }
    }

    private func currentResourceStateAsData() throws -> Data {
        // Update enable flags
        for (i, item) in menuInfo.items.enumerated() {
            menuInfo.setEnabled(item.isEnabled, at: i)
        }

        let writer = BinaryDataWriter()
        writer.write(menuInfo.menuID)
        writer.write(Int16(0)) // width
        writer.write(Int16(0)) // height
        writer.write(menuInfo.mdefID) // mdef ID
        writer.write(Int16(0)) // filler
        writer.write(menuInfo.enableFlags) // enableFlags
        try writer.writePString(menuInfo.name)
        for item in menuInfo.items {
            try writer.writePString(item.name)
            writer.write(item.iconCode)
            writer.write(item.keyCode)
            writer.write(item.markCode)
            writer.write(item.style)

            switch commandSize {
            case .int16:
                if (writer.bytesWritten % 2) != 0 {
                    writer.write(UInt8(0))
                }
                writer.write(UInt16(item.menuCommand))
            case .int32:
                if (writer.bytesWritten % 2) != 0 {
                    writer.write(UInt8(0))
                }
                writer.write(item.menuCommand)
            case .none:
                break
            }
        }
        writer.write(UInt8(0)) // zero terminator
        return writer.data
    }

    /// Write the current state of the ``items`` list back to the resource.
    @IBAction public func saveResource(_ sender: Any) {
        do {
            resource.data = try currentResourceStateAsData()
        } catch {
            self.window?.presentError(error)
        }
        self.setDocumentEdited(false)
    }

    /// Revert the resource to its on-disk state.
    @IBAction public func revertResource(_ sender: Any) {
        undoManager?.removeAllActions()
        self.loadItems()
        menuTable.reloadData()
    }

    @IBAction func createNewItem(_ sender: Any?) {
        var selRow = menuTable.selectedRow
        if selRow == -1 {
            selRow = menuInfo.items.count // No need to subtract 1, because title already offset the index by 1 compared to items.
        }
        menuInfo.items.insert(MenuItem(editor: self), at: selRow)
        menuTable.reloadData()
        menuTable.selectRowIndexes([selRow + 1], byExtendingSelection: false) // +1 to account for title row
        self.setDocumentEdited(true)
    }

    @IBAction func delete(_ sender: Any?) {
        var deletedCount = 0
        for row in menuTable.selectedRowIndexes.reversed() {
            if row > 0 { // Don't allow deleting title.
                menuInfo.items.remove(at: row - 1)
                deletedCount += 1
            }
        }
        if deletedCount > 0 {
            menuTable.reloadData()
            self.setDocumentEdited(true)
        }
        // Undo not fully supported yet
//        do {
//            let oldData = try currentResourceStateAsData()
//            var deletedCount = 0
//            for row in menuTable.selectedRowIndexes.reversed() {
//                if row > 0 { // Don't allow deleting title.
//                    menuInfo.items.remove(at: row - 1)
//                    deletedCount += 1
//                }
//            }
//            if deletedCount > 0 {
//                menuTable.reloadData()
//                undoManager?.setActionName((deletedCount > 0) ? NSLocalizedString("Delete Items", comment: "") : NSLocalizedString("Delete Item", comment: ""))
//                undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
//                self.setDocumentEdited(true)
//            }
//        } catch {
//            self.window?.presentError(error)
//        }
    }

//    private func undoRedoResourceData(_ data: Data) {
//        do {
//            let oldData = try currentResourceStateAsData()
//            undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
//
//            menuInfo = Menu(editor: self)
//            try self.itemsFromData(data)
//            menuTable.reloadData()
//
//            self.setDocumentEdited(true)
//        } catch {
//            self.window?.presentError(error)
//        }
//    }
}

extension MenuEditor: NSTableViewDataSource, NSTableViewDelegate {
    static let titleColumn = NSUserInterfaceItemIdentifier("Name")
    static let shortcutColumn = NSUserInterfaceItemIdentifier("Shortcut")
    static let markColumn = NSUserInterfaceItemIdentifier("Mark")

    @MainActor public func numberOfRows(in tableView: NSTableView) -> Int {
        return menuInfo.items.count + 1
    }

    @MainActor public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if row != 0 {
            return menuInfo.items[row - 1]
        } else {
            return menuInfo
        }
    }

    @MainActor public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        if row == 0 && tableColumn.identifier != Self.titleColumn {
            return nil
        }
        return menuTable.makeView(withIdentifier: tableColumn.identifier, owner: self)
    }

    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
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
        if row > 0 && menuInfo.items[row - 1].name.hasPrefix("-") {
            rowView.contentStyle = .separator
        } else if row > 0 && menuInfo.items[row - 1].hasSubmenu {
            rowView.contentStyle = .submenu
        } else {
            rowView.contentStyle = .normal
        }
        return rowView
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        let selRow = menuTable.selectedRow
        if selRow == -1 {
            selectedMenu = nil
            selectedMenuItem = nil
            selectedItem = nil
        } else if selRow == 0 {
            selectedMenu = menuInfo
            selectedMenuItem = nil
            selectedItem = selectedMenu
        } else {
            selectedMenu = nil
            selectedMenuItem = menuInfo.items[selRow - 1]
            selectedItem = selectedMenuItem
        }
    }
}
