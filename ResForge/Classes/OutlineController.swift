import Cocoa
import RFSupport

class OutlineController: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate, ResourcesView {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet weak var document: ResourceDocument!
    private(set) var currentType: String? = nil
    private var inlineUpdate = false // Flag to prevent reloading items when editing inline
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Note: awakeFromNib is re-triggered each time a cell is created - be careful not to re-sort each time
        if outlineView.sortDescriptors.isEmpty {
            // Default sort resources by id
            outlineView.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        } else if document.directory.sortDescriptors.isEmpty {
            document.directory.sortDescriptors = outlineView.sortDescriptors
        }
    }
    
    @IBAction func doubleClickItems(_ sender: Any) {
        // Ignore double-clicks in table header
        guard outlineView.clickedRow != -1 else {
            return
        }
        // Use hex editor if holding option key
        var editor: ResForgePlugin.Type?
        if NSApp.currentEvent!.modifierFlags.contains(.option) {
            editor = PluginRegistry.hexEditor
        }
        
        for item in outlineView.selectedItems {
            if let resource = item as? Resource {
                document.editorManager.open(resource: resource, using: editor)
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
        if currentType != nil {
            return outlineView.selectedItems as! [Resource]
        } else if deep {
            var resources: [Resource] = []
            for item in outlineView.selectedItems {
                if let item = item as? String {
                    resources.append(contentsOf: document.directory.resourcesByType[item]!)
                } else if let item = item as? Resource, !resources.contains(item) {
                    resources.append(item)
                }
            }
            return resources
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
    
    func updated(resource: Resource, oldIndex: Int, newIndex: Int) {
        let parent = currentType == nil ? resource.type : nil
        if inlineUpdate {
            // The resource has been edited inline, perform the move async to ensure the first responder has been properly updated
            DispatchQueue.main.async { [self] in
                outlineView.moveItem(at: oldIndex, inParent: parent, to: newIndex, inParent: parent)
                outlineView.scrollRowToVisible(outlineView.selectedRow)
            }
        } else {
            outlineView.moveItem(at: oldIndex, inParent: parent, to: newIndex, inParent: parent)
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
                view.textField?.placeholderString = resource.placeholderName()
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
            case "idGroup":
                view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as! NSTableCellView
                view.textField?.stringValue = type
            case "sizeGroup":
                view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as! NSTableCellView
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
        guard let resource = outlineView.item(atRow: outlineView.row(for: textField)) as? Resource else {
            // This can happen if the resource was updated by some other means while the field was in edit mode
            return
        }
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
            return document.directory.filteredResources(type: type)[index]
        } else {
            return document.directory.filteredTypes()[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is String
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let type = item as? String ?? currentType {
            return document.directory.filteredResources(type: type).count
        } else {
            return document.directory.filteredTypes().count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        document.directory.sortDescriptors = outlineView.sortDescriptors
        outlineView.reloadData()
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        // This currently doesn't allow dragging an entire type collection (can still copy/paste it though)
        return item as? Resource
    }
}

extension NSOutlineView {
    var selectedItems: [Any] {
        return self.selectedRowIndexes.map {
            self.item(atRow: $0)!
        }
    }
}
