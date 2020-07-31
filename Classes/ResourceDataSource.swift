import Foundation
import RKSupport

extension Notification.Name {
    static let DataSourceDidAddResource     = Self("DataSourceDidAddResource")
    static let DataSourceDidRemoveResource  = Self("DataSourceDidRemoveResource")
}

class ResourceDataSource: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var document: ResourceDocument!
    var resourcesByType: [String: [Resource]] = [:]
    var allTypes: [String] = []
    @objc var resources: [Resource] {
        return Array(resourcesByType.values.joined())
    }
    private var noReload = false
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(resourceTypeDidChange(_:)), name: .ResourceTypeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDidChange(_:)), name: .ResourceDidChange, object: nil)
    }
    
    // MARK: - Resource management
    
    /// Add an array of resources to the data source. The outline view will be refreshed but there will be no notifications or undo registration.
    @objc func add(resources: [Resource]) {
        for resource in resources {
            self.addToTypedList(resource)
        }
        
        if let outlineView = outlineView {
            if outlineView.sortDescriptors.count == 0 {
                // Default sort resources by id
                outlineView.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
            } else {
                self.outlineView(self.outlineView, sortDescriptorsDidChange:outlineView.sortDescriptors)
            }
        }
    }
    
    @objc func add(_ resource: Resource) {
        self.addToTypedList(resource)
        resource.document = document
        resourcesByType[resource.type]?.sort(using: outlineView.sortDescriptors)
        outlineView.reloadData()
        outlineView.expandItem(resource.type)
        
        NotificationCenter.default.post(name: .DataSourceDidAddResource, object: resource)
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.remove(resource) })
    }
    
    @objc func remove(_ resource: Resource) {
        self.removeFromTypedList(resource)
        outlineView.reloadData()

        NotificationCenter.default.post(name: .DataSourceDidRemoveResource, object: resource)
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.add(resource) })
    }
    
    private func addToTypedList(_ resource: Resource) {
        if resourcesByType[resource.type] != nil {
            resourcesByType[resource.type]!.append(resource)
        } else {
            resourcesByType[resource.type] = [resource]
            allTypes.append(resource.type)
            allTypes.sort()
        }
    }
    
    private func removeFromTypedList(_ resource: Resource, type: String? = nil) {
        let type = type ?? resource.type
        resourcesByType[type]?.removeAll(where: { $0 === resource })
        if resourcesByType[type]?.count == 0 {
            resourcesByType.removeValue(forKey: type)
            allTypes.removeAll(where: { $0 == type })
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
        let oldType = notification.userInfo!["oldValue"] as! String
        self.removeFromTypedList(resource, type: oldType)
        self.addToTypedList(resource)
        resourcesByType[resource.type]?.sort(using: outlineView.sortDescriptors)
        outlineView.reloadData()
        self.select([resource])
    }

    func allResources(ofType type: String) -> [Resource] {
        return resourcesByType[type] ?? []
    }
    
    @objc func findResource(type: String, id: Int) -> Resource? {
        if let resources = resourcesByType[type] {
            for resource in resources where resource.id == id {
                return resource
            }
        }
        return nil
    }
    
    func findResource(type: String, name: String) -> Resource? {
        if let resources = resourcesByType[type] {
            for resource in resources where resource.name == name {
                return resource
            }
        }
        return nil
    }

    /// Tries to return an unused resource ID for a new resource of specified type.
    @objc func uniqueID(for type: String, starting: Int = 128) -> Int {
        var id = starting > Int16.max ? 128 : starting
        let used = self.allResources(ofType: type).map({ $0.id })
        while used.contains(id) {
            id = id == Int16.max ? 128 : id+1
        }
        return id
    }
    
    // MARK: - Outline view management
    
    func select(_ resources: [Resource]) {
        let rows = resources.map { resource -> Int in
            outlineView.expandItem(resource.type)
            return outlineView.row(forItem: resource)
        }
        outlineView.selectRowIndexes(IndexSet(rows), byExtendingSelection: false)
        outlineView.scrollRowToVisible(outlineView.selectedRow)
    }
    
    /// Return a flat list of all resources in the current selection.
    @objc func allSelectedResources() -> [Resource] {
        return self.allResources(for: outlineView.selectedItems)
    }
    
    private func allResources(for items: [Any]) -> [Resource] {
        var resources: [Resource] = []
        for item in items {
            if let item = item as? String {
                resources.append(contentsOf: resourcesByType[item]!)
            } else if let item = item as? Resource, !resources.contains(item) {
                resources.append(item)
            }
        }
        return resources
    }
    
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
                view.textField?.integerValue = resourcesByType[type]!.count // Type count
            default:
                return nil
            }
        }
        return view
    }
    
    // Here we set the values of the resource when editing. We use the shouldEndEditing event for two reasons:
    // 1. Unlike didEndEditing and the control's action, this is only triggered when the field value has actually changed.
    // 2. It allows us to prevent ending editing if a conflict arises.
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        var shouldEnd = true
        if let textField = control as? NSTextField, let resource = outlineView.item(atRow: outlineView.row(for: textField)) as? Resource {
            // We don't need to reload the item after changing values here
            noReload = true
            let tableColumn = outlineView.tableColumns[outlineView.column(for: textField)]
            switch tableColumn.identifier.rawValue {
            case "name":
                resource.name = textField.stringValue
            case "type":
                shouldEnd = resource.setType(textField.stringValue)
            case "id":
                shouldEnd = resource.setID(textField.integerValue)
            default:
                break
            }
            noReload = false
        }
        return shouldEnd
    }
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        let view = outlineView.view(atColumn: 0, row: outlineView.row(forItem: resource), makeIfNecessary: false) as? NSTableCellView
        view?.textField?.placeholderString = ApplicationDelegate.placeholderName(for: resource)
        if !noReload {
            outlineView.reloadItem(resource)
        }
    }

    // MARK: - DataSource protocol functions
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let type = item as? String {
            return resourcesByType[type]![index]
        } else {
            return allTypes[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is String
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            return allTypes.count
        } else if let type = item as? String {
            return resourcesByType[type]!.count
        } else {
            return 0
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        for type in allTypes {
            resourcesByType[type]?.sort(using: outlineView.sortDescriptors)
        }
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
            document.pasteResources(resources)
            return true
        }
        return false
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Sort the collection using an array of NSSortDescriptors, such as those obtained from as NSTableView.
    mutating func sort(using descriptors: [NSSortDescriptor]) {
        self.sort {
            for descriptor in descriptors {
                switch descriptor.compare($0, to: $1) {
                case .orderedAscending:
                    return true
                case .orderedDescending:
                    return false
                default:
                    continue
                }
            }
            return false
        }
    }
}
