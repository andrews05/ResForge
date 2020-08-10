import Foundation
import RKSupport

extension Notification.Name {
    static let CollectionDidAddResource     = Self("CollectionDidAddResource")
    static let CollectionDidRemoveResource  = Self("CollectionDidRemoveResource")
}

class ResourceCollection {
    let document: ResourceDocument!
    var resourcesByType: [String: [Resource]] = [:]
    var allTypes: [String] = []
    var resources: [Resource] {
        return Array(resourcesByType.values.joined())
    }
    var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
            for type in allTypes {
                resourcesByType[type]?.sort(using: sortDescriptors)
            }
        }
    }
    
    init() {
        document = nil
    }
    
    init(_ document: ResourceDocument) {
        self.document = document
        NotificationCenter.default.addObserver(self, selector: #selector(resourceTypeDidChange(_:)), name: .ResourceTypeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDidChange(_:)), name: .ResourceDidChange, object: nil)
    }
    
    /// Remove all resources.
    func reset() {
        resourcesByType.removeAll()
        allTypes.removeAll()
    }
    
    /// Add an array of resources with no notification or undo registration.
    func add(_ resources: [Resource]) {
        for resource in resources {
            self.addToTypedList(resource)
        }
        for type in allTypes {
            resourcesByType[type]?.sort(using: sortDescriptors)
        }
    }
    
    /// Add a single resource.
    func add(_ resource: Resource) -> Resource {
        self.addToTypedList(resource)
        resourcesByType[resource.type]?.sort(using: sortDescriptors)
        
        NotificationCenter.default.post(name: .CollectionDidAddResource, object: self, userInfo: ["resource": resource])
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.remove(resource) })
        return resource
    }
    
    /// Remove a single resource.
    func remove(_ resource: Resource) {
        self.removeFromTypedList(resource)

        NotificationCenter.default.post(name: .CollectionDidRemoveResource, object: self, userInfo: ["resource": resource])
        document.undoManager?.registerUndo(withTarget: self, handler: { _ = $0.add(resource) })
    }
    
    private func addToTypedList(_ resource: Resource) {
        resource.document = document
        if resourcesByType[resource.type] == nil {
            resourcesByType[resource.type] = [resource]
            allTypes.append(resource.type)
            allTypes.sort()
        } else {
            resourcesByType[resource.type]!.append(resource)
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
        // Currently the type list gets sorted twice - this one seems redundant but it's important to do this before the data source receives the notification
        resourcesByType[resource.type]!.sort(using: sortDescriptors)
    }
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        resourcesByType[resource.type]!.sort(using: sortDescriptors)
    }

    func allResources(ofType type: String) -> [Resource] {
        return resourcesByType[type] ?? []
    }
    
    func findResource(type: String, id: Int) -> Resource? {
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

    /// Return an unused resource ID for a new resource of specified type.
    func uniqueID(for type: String, starting: Int = 128) -> Int {
        // Get a sorted list of used ids
        let used = self.allResources(ofType: type).map({ $0.id }).sorted()
        // Find the index of the starting id
        guard var i = used.firstIndex(where: { $0 == starting }) else {
            return starting
        }
        // Keep incrementing the id until we find an unused one
        // (This method is much faster than repeatedly calling contains())
        var id = starting
        while i != used.endIndex && id == used[i] {
            if id == Int16.max {
                id = min(used[0], 128)
                i = 0
            } else {
                id = id+1
                i = i+1
            }
        }
        return id
    }
}

extension MutableCollection where Self: RandomAccessCollection {
    /// Sort the collection using an array of NSSortDescriptors, such as those obtained from an NSTableView.
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
