import AppKit
import SwiftUI
import RFSupport

extension NSPasteboard.PasteboardType {
    static let RFDialogItem = Self("com.resforge.dialog-item")
}

class DialogEditorWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = [
        "DITL",
    ]
    
    let resource: Resource
    let createMenuTitle: String? = "Add Dialog Item"
    private let manager: RFEditorManager
    @IBOutlet var documentView: DITLDocumentView!
    @IBOutlet var tabView: NSTabView!
    @IBOutlet var itemList: NSTableView!
    @objc dynamic var selectedItem: DITLItemView?
    @objc dynamic var hasSelection = false
    private var items = [DITLItemView]()
    private var isSelectingItems = false

    override var windowNibName: String {
        return "DialogEditorWindow"
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
        self.loadDLOG()
        self.updateView()

        // Allow re-arranging the items
        itemList.registerForDraggedTypes([.RFDialogItem])
    }
    
    func reflectSelectedItem() {
        let selection = items.filter(\.selected)
        selectedItem = selection.count == 1 ? selection[0] : nil
        hasSelection = !selection.isEmpty
        switch selectedItem?.type {
        case .button, .checkBox, .radioButton, .staticText, .editText:
            tabView.selectTabViewItem(at: 0)
        case .control, .icon, .picture:
            tabView.selectTabViewItem(at: 1)
        case .helpItem:
            tabView.selectTabViewItem(at: 2)
        default:
            tabView.selectTabViewItem(at: 3)
        }
    }
    
    func selectionDidChange() {
        isSelectingItems = true
        let indices = items.enumerated()
            .filter { $0.1.selected }
            .map { $0.0 }
        itemList.selectRowIndexes(IndexSet(indices), byExtendingSelection: false)
        self.reflectSelectedItem()
        isSelectingItems = false
    }
    
    /// Reload the views representing our ``items`` list.
    private func updateView() {
        documentView.subviews = items
        itemList.reloadData()
    }

    private func itemsFromData(_ data: Data) throws {
        let reader = BinaryDataReader(data)
        let itemCountMinusOne: Int16 = try reader.read()
        for _ in 0...itemCountMinusOne {
            let item = try DITLItemView(reader, manager: manager)
            items.append(item)
        }
    }
    
    /// Parse the resource into our ``items`` list.
    private func loadItems() {
        items = []
        if resource.data.isEmpty {
            self.setDocumentEdited(true)
        } else {
            do {
                try itemsFromData(resource.data)
            } catch {
                window?.presentError(error)
            }
        }
    }

    private func loadDLOG() {
        guard let dlog = manager.findResource(type: ResourceType("DLOG"), id: resource.id)
                ?? manager.findResource(type: ResourceType("ALRT"), id: resource.id)
        else {
            return
        }
        do {
            // Note we don't check here whether the DLOG actually references this DITL
            let reader = BinaryDataReader(dlog.data)
            let top = Int(try reader.read() as Int16)
            let left = Int(try reader.read() as Int16)
            let bottom = Int(try reader.read() as Int16)
            let right = Int(try reader.read() as Int16)
            var size = NSSize(width: right - left, height: bottom - top)
            documentView.dialogBounds = NSRect(origin: .zero, size: size)
            size.width += (window?.contentView?.frame.width ?? 0) - (documentView.enclosingScrollView?.documentVisibleRect.width ?? 0) + 16
            size.height += 16
            window?.setContentSize(size)
        } catch {
            // Ignore
        }
    }
    
    private func currentResourceStateAsData() throws -> Data {
        let writer = BinaryDataWriter()
        let numItems = Int16(items.count) - 1
        writer.write(numItems)
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
            self.presentError(error)
        }
        self.setDocumentEdited(false)
    }
    
    /// Revert the resource to its on-disk state.
    @IBAction func revertResource(_ sender: Any) {
        window?.undoManager?.removeAllActions()
        self.loadItems()
        self.updateView()
        self.setDocumentEdited(false)
    }
    
    override func selectAll(_ sender: Any?) {
        itemList.selectAll(sender)
    }

    func deselectAll(_ sender: Any?) {
        itemList.deselectAll(sender)
    }

    @IBAction func createNewItem(_ sender: Any?) {
        var newItems = items
        let newItem = DITLItemView(frame: NSRect(x: 10, y: 10, width: 80, height: 20), text: "Button", type: .button, manager: manager)
        newItems.append(newItem)
        window?.undoManager?.setActionName(NSLocalizedString("Create Item", comment: ""))
        self.undoRedoItems(newItems)
    }
    
    @IBAction func delete(_ sender: Any?) {
        let remainingItems = items.filter { !$0.selected }
        if remainingItems.count != items.count {
            window?.undoManager?.setActionName(NSLocalizedString("Delete Item", comment: ""))
            self.undoRedoItems(remainingItems)
        }
    }
    
    private func undoRedoItems(_ newItems: [DITLItemView], selectDiff: Bool = true) {
        if selectDiff {
            for item in newItems {
                item.selected = !items.contains(item)
            }
        }
        let oldItems = items
        items = newItems
        window?.undoManager?.registerUndo(withTarget: self) { $0.undoRedoItems(oldItems, selectDiff: selectDiff) }
        self.setDocumentEdited(true)
        self.updateView()
        self.selectionDidChange()
    }
}

extension DialogEditorWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn else { return nil }
        let view = tableView.makeView(withIdentifier: tableColumn.identifier, owner: self) as! NSTableCellView
        if tableColumn.identifier.rawValue == "num" {
            view.textField?.integerValue = row
        } else if tableColumn.identifier.rawValue == "name" {
            let item = items[row]
            view.textField?.placeholderString = item.type.name
            view.textField?.stringValue = item.text
        }
        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingItems else {
            return
        }
        for (i, item) in items.enumerated() {
            item.selected = itemList.isRowSelected(i)
        }
        self.reflectSelectedItem()

        // If single item selected, scroll to it
        if itemList.selectedRowIndexes.count == 1 {
            let item = items[itemList.selectedRow]
            item.scrollToVisible(item.bounds.insetBy(dx: -4, dy: -4))
        }
    }

    // MARK: - Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        let item = NSPasteboardItem()
        item.setString("\(row)", forType: .RFDialogItem)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above && (info.draggingSource as? NSView) == tableView {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let pbItems = (info.draggingPasteboard.readObjects(forClasses: [NSPasteboardItem.self]) as? [NSPasteboardItem]) else {
            return false
        }
        let indexes = pbItems.compactMap({ $0.string(forType: .RFDialogItem) }).compactMap(Int.init)

        var newItems = items
        newItems.move(fromOffsets: IndexSet(indexes), toOffset: row)
        self.undoRedoItems(newItems, selectDiff: false)

        return true
    }
}
