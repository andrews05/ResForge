import Foundation
import RKSupport

extension Notification.Name {
    static let DataSourceDidAddResource     = Self("DataSourceDidAddResource")
    static let DataSourceDidRemoveResource  = Self("DataSourceDidRemoveResource")
}

class ResourceDataSource: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var document: ResourceDocument!
    var resourcesByType: [String: [Resource]] = [:]
    var allTypes: [String] = []
    @objc var resources: [Resource] {
        return Array(resourcesByType.values.joined())
    }
    
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
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        let column = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
        let cell = column?.dataCell(forRow: outlineView.row(forItem: resource)) as! NSTextFieldCell
        cell.placeholderString = self.placeholder(for: resource)
        outlineView.reloadItem(notification.object)
    }
    
    func placeholder(for resource: Resource) -> String {
        if resource.id == -16455 {
            // don't bother checking type since there are too many icon types
            return NSLocalizedString("Custom Icon", comment: "")
        }
        
        switch resource.type {
        case "carb":
            if resource.id == 0 {
                return NSLocalizedString("Carbon Identifier", comment: "")
            }
        case "pnot":
            if resource.id == 0 {
                return NSLocalizedString("File Preview", comment: "")
            }
        case "STR ":
            if resource.id == -16396 {
                return NSLocalizedString("Creator Information", comment: "")
            }
        case "vers":
            if resource.id == 1 {
                return NSLocalizedString("File Version", comment: "")
            } else if resource.id == 2 {
                return NSLocalizedString("Package Version", comment: "")
            }
        default:
            return NSLocalizedString("Untitled Resource", comment: "")
        }
        return ""
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
        return item is Resource
    }
    
    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        if let cell = cell as? ResourceNameCell {
            if let resource = item as? Resource {
                // set resource icon
                cell.drawImage = true
                cell.image = ApplicationDelegate.icon(for: resource.type)
                cell.placeholderString = self.placeholder(for: resource)
            } else {
                cell.drawImage = false
            }
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
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if let resource = item as? Resource {
            switch tableColumn!.identifier.rawValue {
            case "name":
                return resource.name
            case "type":
                return resource.type
            case "id":
                return resource.id
            case "size":
                return resource.data.count
            case "attributes":
                return resource.attributes
            default:
                break
            }
        } else if let type = item as? String {
            switch tableColumn!.identifier.rawValue {
            case "name":
                return item // Type header
            case "size":
                return resourcesByType[type]!.count // Type count
            default:
                break
            }
        }
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
        guard let resource = item as? Resource else {
            return
        }
        switch tableColumn!.identifier.rawValue {
        case "name":
            resource.name = object as? String ?? ""
        case "type":
            if !resource.setType(object as! String) {
                outlineView.reloadItem(item)
            }
        case "id":
            if !resource.setID(object as! Int) {
                outlineView.reloadItem(item)
            }
        default:
            break
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
