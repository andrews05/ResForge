import Cocoa
import RKSupport

class ResourceDataSource: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var document: ResourceDocument!
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
        document.undoManager?.disableUndoRegistration()
        self.reload(selecting: [resource])
        document.undoManager?.enableUndoRegistration()
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
        let offset = outlineView.row(forItem: resource.type) + 1
        let newRow = document.collection.resourcesByType[resource.type]!.firstIndex(of: resource)!
        outlineView.moveItem(at: row-offset, inParent: resource.type, to: newRow, inParent: resource.type)
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
    
    /// Reload the data source and select the given resources, expanding type lists as necessary.
    func reload(selecting resources: [Resource]? = nil) {
        outlineView.reloadData()
        if let resources = resources {
            self.select(resources)
            outlineView.window?.makeFirstResponder(outlineView) // Outline view seems to lose focus without this?
        }
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.willReload(resources) })
    }
    
    func select(_ resources: [Resource]) {
        let rows = resources.map { resource -> Int in
            outlineView.expandItem(resource.type)
            return outlineView.row(forItem: resource)
        }
        outlineView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
        outlineView.scrollRowToVisible(outlineView.selectedRow)
    }
    
    /// Return a flat list of all resources in the current selection.
    func allSelectedResources() -> [Resource] {
        return self.allResources(for: outlineView.selectedItems)
    }
    
    private func allResources(for items: [Any]) -> [Resource] {
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
        var view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
        if let resource = item as? Resource {
            switch tableColumn!.identifier.rawValue {
            case "name":
                view.textField?.stringValue = resource.name
                view.textField?.isEditable = true
                view.textField?.placeholderString = ApplicationDelegate.placeholderName(for: resource)
                view.imageView?.image = ApplicationDelegate.icon(for: resource.type)
            case "type":
                view.textField?.stringValue = resource.type
                view.textField?.isEditable = true
            case "id":
                view.textField?.integerValue = resource.id
                view.textField?.isEditable = true
            case "size":
                view.textField?.integerValue = resource.data.count
            case "attributes":
                view.textField?.objectValue = resource.attributes
            default:
                return nil
            }
        } else if let type = item as? String {
            switch tableColumn!.identifier.rawValue {
            case "name":
                view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "type"), owner: self) as! NSTableCellView
                view.textField?.stringValue = type // Type header
                view.textField?.isEditable = false
            case "size":
                view.textField?.integerValue = document.collection.resourcesByType[type]!.count // Type count
            default:
                return nil
            }
        }
        return view
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
        if let type = item as? String {
            return document.collection.resourcesByType[type]![index]
        } else {
            return document.collection.allTypes[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is String
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return document.collection.allTypes.count
        } else if let type = item as? String {
            return document.collection.resourcesByType[type]!.count
        } else {
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        document.collection.sortDescriptors = outlineView.sortDescriptors
        outlineView.reloadData()
    }
    
    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: allResources(for: items))
        pasteboard.setData(data, forType: .RKResource)
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if info.draggingSource as? NSOutlineView === self.outlineView {
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
}
