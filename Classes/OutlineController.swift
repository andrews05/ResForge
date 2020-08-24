import Cocoa
import RKSupport

class OutlineController: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate, ResourcesView {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var document: ResourceDocument!
    private var currentType: String? = nil
    private var inlineUpdate = false // Flag to prevent reloading items when editing inline
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // awakeFromNib is re-triggered each time a cell is created - make sure we only do this once
        if outlineView.registeredDraggedTypes.count == 0 {
            outlineView.registerForDraggedTypes([.RKResource])
            if outlineView.sortDescriptors.count == 0 {
                // Default sort resources by id
                outlineView.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            } else {
                document.directory.sortDescriptors = outlineView.sortDescriptors
            }
        }
    }
    
    @IBAction func doubleClickItems(_ sender: Any) {
        // Ignore double-clicks in table header
        guard outlineView.clickedRow != -1 else {
            return
        }
        // Use hex editor if holding option key
        var editor: ResKnifePlugin.Type?
        if NSApp.currentEvent!.modifierFlags.contains(.option) {
            editor = PluginManager.hexEditor
        }
        
        for item in outlineView.selectedItems {
            if let resource = item as? Resource {
                document.pluginManager.open(resource: resource, using: editor, template: nil)
            } else {
                // Expand the type list
                outlineView.expandItem(item)
            }
        }
    }
    
    func reload(type: String?) {
        currentType = type
        outlineView.reloadData()
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
    
    func selectionCount() -> Int {
        return outlineView.numberOfSelectedRows
    }
    
    func selectedResources(deep: Bool = false) -> [Resource] {
        if deep {
            return self.resources(for: outlineView.selectedItems)
        } else {
            return outlineView.selectedItems.compactMap({ $0 as? Resource })
        }
    }
    
    func selectedType() -> String? {
        if currentType == nil {
            let item = outlineView.item(atRow: outlineView.selectedRow)
            return item as? String ?? (item as? Resource)?.type
        } else {
            return currentType == "" ? nil : currentType
        }
    }
    
    private func resources(for items: [Any]) -> [Resource] {
        var resources: [Resource] = []
        for item in items {
            if let item = item as? String {
                resources.append(contentsOf: document.directory.resourcesByType[item]!)
            } else if let item = item as? Resource, !resources.contains(item) {
                resources.append(item)
            }
        }
        return resources
    }
    
    func changed(resource: Resource, newIndex: Int) {
        // Update the position
        let row = outlineView.row(forItem: resource)
        if currentType != nil {
            outlineView.moveItem(at: row, inParent: nil, to: newIndex, inParent: nil)
        } else {
            let offset = outlineView.row(forItem: resource.type) + 1
            outlineView.moveItem(at: row-offset, inParent: resource.type, to: newIndex, inParent: resource.type)
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
                view.textField?.integerValue = document.directory.resourcesByType[type]!.count
            default:
                return nil
            }
            return view
        }
        return nil
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
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
    
    // MARK: - DataSource functions
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let type = item as? String ?? currentType {
            return document.directory.resourcesByType[type]![index]
        } else {
            return document.directory.allTypes[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is String
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let type = item as? String ?? currentType {
            return document.directory.resourcesByType[type]?.count ?? 0
        } else {
            return document.directory.allTypes.count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        document.directory.sortDescriptors = outlineView.sortDescriptors
        outlineView.reloadData()
    }
    
    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: self.resources(for: items))
        pasteboard.setData(data, forType: .RKResource)
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if info.draggingSource as AnyObject === outlineView {
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

extension NSOutlineView {
    var selectedItems: [Any] {
        return self.selectedRowIndexes.map {
            self.item(atRow: $0)!
        }
    }
}
