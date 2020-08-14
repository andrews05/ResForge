import Cocoa
import RKSupport

class ResourceDataSource: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate, NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var typeList: NSTableView!
    @IBOutlet var splitView: NSSplitView!
    @IBOutlet weak var document: ResourceDocument!
    private(set) var useTypeList = UserDefaults.standard.bool(forKey: kShowSidebar)
    private var currentType: String? = nil
    private var inlineUpdate = false // Flag to prevent reloading items when editing inline
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // awakeFromNib is re-triggered each time a cell is created - to ensure we only do this once, check the registered dragged types
        if outlineView.registeredDraggedTypes.count == 0 {
            NotificationCenter.default.addObserver(self, selector: #selector(resourceTypeDidChange(_:)), name: .ResourceTypeDidChange, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(resourceDidChange(_:)), name: .ResourceDidChange, object: nil)

            outlineView.registerForDraggedTypes([.RKResource])
            if outlineView.sortDescriptors.count == 0 {
                // Default sort resources by id
                outlineView.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            } else {
                document.collection.sortDescriptors = outlineView.sortDescriptors
            }
            if useTypeList {
                // Select first type by default
                typeList.selectRowIndexes(IndexSet(integer: 1), byExtendingSelection: false)
            } else {
                // Showing the sidebar here when it is already visible seems to cause problems - only update if it should be hidden
                self.updateSidebar()
            }
        }
    }
    
    @objc func resourceTypeDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        self.reload(selecting: [resource], withUndo: false)
    }
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        // Update the position
        let row = outlineView.row(forItem: resource)
        let newRow = document.collection.resourcesByType[resource.type]!.firstIndex(of: resource)!
        if useTypeList {
            outlineView.moveItem(at: row, inParent: nil, to: newRow, inParent: nil)
        } else {
            let offset = outlineView.row(forItem: resource.type) + 1
            outlineView.moveItem(at: row-offset, inParent: resource.type, to: newRow, inParent: resource.type)
        }
        if inlineUpdate {
            outlineView.scrollRowToVisible(outlineView.selectedRow)
            // Update the placeholder
            let view = outlineView.view(atColumn: 0, row: outlineView.selectedRow, makeIfNecessary: false) as? NSTableCellView
            view?.textField?.placeholderString = ApplicationDelegate.placeholderName(for: resource)
        } else {
            outlineView.reloadItem(resource)
        }
    }
    
    // MARK: - Resource management
    
    /// Reload the data source after performing a given operation. The resources returned from the operation will be selected.
    ///
    /// This function is important for managing undo operations when adding/removing resources. It creates an undo group and ensures that the data source is always reloaded after the operation is peformed, even when undoing/redoing.
    func reload(after operation: () -> [Resource]?) {
        document.undoManager?.beginUndoGrouping()
        self.willReload()
        self.reload(selecting: operation())
        document.undoManager?.endUndoGrouping()
    }
    
    /// Register intent to reload the data source before performing changes.
    private func willReload(_ resources: [Resource]? = nil) {
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.reload(selecting: resources) })
    }
    
    /// Reload the view and select the given resources.
    func reload(selecting resources: [Resource]? = nil, withUndo: Bool = true) {
        typeList.reloadData()
        if useTypeList, let type = resources?.first?.type ?? currentType,
            let i = document.collection.allTypes.firstIndex(of: type) {
            typeList.selectRowIndexes(IndexSet(integer: i+1), byExtendingSelection: false)
        } else {
            currentType = nil
            outlineView.reloadData()
        }
        if let resources = resources {
            self.select(resources)
        }
        if withUndo {
            document.undoManager?.registerUndo(withTarget: self, handler: { $0.willReload(resources) })
        }
    }
    
    func select(_ resources: [Resource]) {
        let rows = resources.compactMap { resource -> Int? in
            outlineView.expandItem(resource.type)
            let i = outlineView.row(forItem: resource)
            return i == -1 ? nil : i
        }
        outlineView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
        outlineView.scrollRowToVisible(outlineView.selectedRow)
    }
    
    /// Return the currently selected type.
    func selectedType() -> String? {
        if useTypeList {
            return currentType
        } else {
            let item = outlineView.item(atRow: outlineView.selectedRow)
            return item as? String ?? (item as? Resource)?.type
        }
    }
    
    /// Return a flat list of all resources in the current selection, optionally including resources within selected type lists.
    func selectedResources(deep: Bool = false) -> [Resource] {
        if deep {
            return self.resources(for: outlineView.selectedItems)
        } else {
            return outlineView.selectedItems.compactMap({ $0 as? Resource })
        }
    }
    
    private func resources(for items: [Any]) -> [Resource] {
        var resources: [Resource] = []
        for item in items {
            if let item = item as? String {
                resources.append(contentsOf: document.collection.resourcesByType[item]!)
            } else if let item = item as? Resource, !resources.contains(item) {
                resources.append(item)
            }
        }
        return resources
    }
    
    // MARK: - Delegate functions
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view: NSTableCellView
        if let resource = item as? Resource {
            view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
            switch tableColumn!.identifier.rawValue {
            case "name":
                view.textField?.stringValue = resource.name
                view.textField?.placeholderString = ApplicationDelegate.placeholderName(for: resource)
                view.imageView?.image = ApplicationDelegate.icon(for: resource.type)
            case "type":
                view.textField?.stringValue = resource.type
            case "id":
                view.textField?.integerValue = resource.id
            case "size":
                view.textField?.integerValue = resource.data.count
            case "attributes":
                view.textField?.objectValue = resource.attributes
            default:
                return nil
            }
            return view
        } else if let type = item as? String {
            let identifier = tableColumn!.identifier.rawValue.appending("Group")
            switch identifier {
            case "nameGroup":
                view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier), owner: self) as! NSTableCellView
                view.textField?.stringValue = type
            case "sizeGroup":
                view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier), owner: self) as! NSTableCellView
                view.textField?.integerValue = document.collection.resourcesByType[type]!.count
            default:
                return nil
            }
            return view
        }
        return nil
    }
    
    // Check for conflicts
    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        let textField = control as! NSTextField
        let resource = outlineView.item(atRow: outlineView.row(for: textField)) as! Resource
        switch textField.identifier?.rawValue {
        case "type":
            return resource.canSetType(obj as! String)
        case "id":
            return resource.canSetID(obj as! Int)
        default:
            break
        }
        return true
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        let textField = obj.object as! NSTextField
        let resource = outlineView.item(atRow: outlineView.row(for: textField)) as! Resource
        // We don't need to reload the item after changing values here
        inlineUpdate = true
        switch textField.identifier?.rawValue {
        case "name":
            resource.name = textField.stringValue
        case "type":
            resource.type = textField.stringValue
        case "id":
            resource.id = textField.integerValue
        default:
            break
        }
        inlineUpdate = false
    }

    // MARK: - DataSource protocol functions
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let type = item as? String ?? currentType {
            return document.collection.resourcesByType[type]![index]
        } else {
            return document.collection.allTypes[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is String
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let type = item as? String ?? currentType {
            return document.collection.resourcesByType[type]!.count
        } else if !useTypeList {
            return document.collection.allTypes.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        document.collection.sortDescriptors = outlineView.sortDescriptors
        outlineView.reloadData()
    }
    
    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: self.resources(for: items))
        pasteboard.setData(data, forType: .RKResource)
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if info.draggingSource as? NSOutlineView === outlineView {
            return []
        }
        outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return .copy
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        if let data = info.draggingPasteboard.data(forType: .RKResource),
            let resources = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Resource] {
            document.add(resources: resources)
            return true
        }
        return false
    }

    // MARK: - Sidebar functions
    
    func toggleSidebar() {
        if !useTypeList {
            // Try to make sure sure a type is selected when showing the sidebar
            currentType = self.selectedType() ?? outlineView.item(atRow: 0) as? String
        }
        useTypeList = !useTypeList
        self.updateSidebar()
        self.reload(selecting: self.selectedResources(), withUndo: false)
        UserDefaults.standard.set(useTypeList, forKey: kShowSidebar)
    }
    
    private func updateSidebar() {
        splitView.setPosition(useTypeList ? 100 : 0, ofDividerAt: 0)
        outlineView.indentationPerLevel = useTypeList ? 0 : 1
    }
    
    // Prevent dragging the divider
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        return NSZeroRect
    }
    
    // Sidebar width should remain fixed
    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        return splitView.subviews[1] === view
    }
    
    // Allow sidebar to collapse
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 2
    }
    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return splitView.subviews[0] === subview
    }
    
    // Hide divider when sidebar collapsed
    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let identifier = tableColumn?.identifier {
            let type = document.collection.allTypes[row-1]
            let count = String(document.collection.resourcesByType[type]!.count)
            let view = tableView.makeView(withIdentifier: identifier, owner: self) as! NSTableCellView
            view.textField?.stringValue = type
            (view.subviews.last as? NSButton)?.title = count
            return view
        } else {
            return tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderCell"), owner: self) as! NSTableCellView
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return document.collection.allTypes.count + 1
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return row != 0
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return row == 0
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if useTypeList && typeList.selectedRow > 0 {
            currentType = document.collection.allTypes[typeList.selectedRow-1]
        } else {
            currentType = nil
        }
        outlineView.reloadData()
    }
}

// Prevent the source list from becoming first responder
class SourceList: NSTableView {
    override var acceptsFirstResponder: Bool { false }
}
