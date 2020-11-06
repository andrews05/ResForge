import Foundation
import RKSupport

extension Notification.Name {
    static let DirectoryDidAddResource      = Self("DirectoryDidAddResource")
    static let DirectoryDidRemoveResource   = Self("DirectoryDidRemoveResource")
    static let DirectoryDidUpdateResource   = Self("DirectoryDidUpdateResource")
}

class ResourceDirectory {
    private(set) weak var document: ResourceDocument!
    private(set) var resourcesByType: [String: [Resource]] = [:]
    private(set) var allTypes: [String] = []
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
    }
    
    /// Add a single resource.
    func add(_ resource: Resource) {
        self.addToTypedList(resource)
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.remove(resource) })
        NotificationCenter.default.post(name: .DirectoryDidAddResource, object: self, userInfo: ["resource": resource])
        document.updateStatus()
    }
    
    /// Remove a single resource.
    func remove(_ resource: Resource) {
        self.removeFromTypedList(resource)
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.add(resource) })
        NotificationCenter.default.post(name: .DirectoryDidRemoveResource, object: self, userInfo: ["resource": resource])
        document.updateStatus()
    }
    
    private func addToTypedList(_ resource: Resource) {
        resource.document = document
        if resourcesByType[resource.type] == nil {
            resourcesByType[resource.type] = [resource]
            allTypes.append(resource.type)
            allTypes.sort(by: { $0.localizedCompare($1) == .orderedAscending })
        } else {
            resourcesByType[resource.type]!.insert(resource, using: sortDescriptors)
        }
    }
    
    private func removeFromTypedList(_ resource: Resource, type: String? = nil) {
        let type = type ?? resource.type
        resourcesByType[type]?.removeFirst(resource)
        if resourcesByType[type]?.count == 0 {
            resourcesByType.removeValue(forKey: type)
            allTypes.removeFirst(type)
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
    }
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document,
            let idx = resourcesByType[resource.type]!.firstIndex(of: resource)
        else {
            return
        }
        resourcesByType[resource.type]!.sort(using: sortDescriptors)
        let newIdx = resourcesByType[resource.type]!.firstIndex(of: resource)!
        NotificationCenter.default.post(name: .DirectoryDidUpdateResource, object: self, userInfo: [
            "resource": resource,
            "oldIndex": idx,
            "newIndex": newIdx
        ])
    }
    
    var count: Int {
        resourcesByType.flatMap { $1 }.count
    }
    
    func resources() -> [Resource] {
        return Array(resourcesByType.values.joined())
    }

    func resources(ofType type: String) -> [Resource] {
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
        let used = self.resources(ofType: type).map({ $0.id }).sorted()
        // Find the index of the starting id
        guard var i = used.firstIndex(where: { $0 == starting }) else {
            return starting
        }
        // Keep incrementing the id until we find an unused one
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

// MARK: - Sorted Array extensions

extension Array where Element: NSSortDescriptor {
    /// Compare two elements using all the descriptors in this array.
    func compare<T>(_ a: T, _ b: T) -> Bool {
        for descriptor in self {
            switch descriptor.compare(a, to: b) {
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

extension Array where Element: Equatable {
    /// Sort the array using an array of NSSortDescriptors, such as those obtained from an NSTableView.
    mutating func sort(using descriptors: [NSSortDescriptor]) {
        if !descriptors.isEmpty {
            self.sort(by: descriptors.compare)
        }
    }
    
    /// Insert an element into the sorted array at the position appropriate for the given NSSortDescriptors.
    mutating func insert(_ newElement: Element, using descriptors: [NSSortDescriptor]) {
        if !descriptors.isEmpty {
            var slice : SubSequence = self[...]
            // Perform a binary search
            while !slice.isEmpty {
                let middle = slice.index(slice.startIndex, offsetBy: slice.count / 2)
                if descriptors.compare(slice[middle], newElement) {
                    slice = slice[index(after: middle)...]
                } else {
                    slice = slice[..<middle]
                }
            }
            self.insert(newElement, at: slice.startIndex)
        } else {
            self.append(newElement)
        }
    }
    
    /// Remove the first occurence of a given element.
    mutating func removeFirst(_ item: Element) {
        if let i = self.firstIndex(of: item) {
            self.remove(at: i)
        }
    }
}
