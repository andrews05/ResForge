import Foundation
import RFSupport

extension Notification.Name {
    static let DirectoryDidAddResource      = Self("DirectoryDidAddResource")
    static let DirectoryDidRemoveResource   = Self("DirectoryDidRemoveResource")
    static let DirectoryDidUpdateResource   = Self("DirectoryDidUpdateResource")
}

class ResourceDirectory {
    private(set) weak var document: ResourceDocument!
    private(set) var resourcesByType: [ResourceType: [Resource]] = [:]
    private(set) var allTypes: [ResourceType] = []
    private var filtered: [ResourceType: [Resource]] = [:]
    var ignoreChanges = false
    var filter = "" {
        didSet {
            filtered = [:]
        }
    }
    var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
            if sortDescriptors.count == 1 && sortDescriptors[0].key == "id" && sortDescriptors[0].ascending {
                sortDescriptors = []
            }
            if sortDescriptors != oldValue {
                filtered = [:]
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
        filtered = [:]
    }
    
    /// Add a single resource.
    func add(_ resource: Resource) {
        self.addToTypedList(resource)
        filtered.removeValue(forKey: resource.type)
        document.undoManager?.registerUndo(withTarget: self) { $0.remove(resource) }
        NotificationCenter.default.post(name: .DirectoryDidAddResource, object: self, userInfo: ["resource": resource])
    }
    
    /// Remove a single resource.
    func remove(_ resource: Resource) {
        self.removeFromTypedList(resource)
        filtered.removeValue(forKey: resource.type)
        document.undoManager?.registerUndo(withTarget: self) { $0.add(resource) }
        NotificationCenter.default.post(name: .DirectoryDidRemoveResource, object: self, userInfo: ["resource": resource])
    }
    
    /// Get the resources for the given type that match the current filter.
    func filteredResources(type: ResourceType) -> [Resource] {
        if filter.isEmpty && sortDescriptors.isEmpty {
            return resourcesByType[type] ?? []
        }
        // Maintain a cache of the filtered resources
        if filtered[type] == nil, var resouces = resourcesByType[type] {
            if !filter.isEmpty {
                let id = Int(filter)
                resouces = resouces.filter {
                    return $0.id == id || $0.name.localizedCaseInsensitiveContains(filter)
                }
            }
            resouces.sort(using: sortDescriptors)
            filtered[type] = resouces
        }
        return filtered[type] ?? []
    }
    
    /// Get all types that contain resources matching the current filter.
    func filteredTypes() -> [ResourceType] {
        if filter.isEmpty {
            return allTypes
        }
        return allTypes.compactMap {
            self.filteredResources(type: $0).isEmpty ? nil : $0
        }
    }
    
    /// Get the count of resources matching the current filter.
    func filteredCount(type: ResourceType? = nil) -> Int {
        let list = filter.isEmpty ? resourcesByType : filtered
        if let type = type {
            return list[type]?.count ?? 0
        } else {
            return list.reduce(0) { $0 + $1.value.count }
        }
    }
    
    private func addToTypedList(_ resource: Resource) {
        resource.document = document
        if resourcesByType[resource.type] == nil {
            resourcesByType[resource.type] = [resource]
            allTypes.insert(resource.type) {
                let compare = $0.code.localizedCompare($1.code)
                return compare == .orderedSame ? $0.attributes.count < $1.attributes.count : compare == .orderedAscending
            }
        } else {
            resourcesByType[resource.type]!.insert(resource) { $0.id < $1.id }
        }
    }
    
    private func removeFromTypedList(_ resource: Resource, type: ResourceType? = nil) {
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
            resource.document === document,
            let oldType = notification.userInfo?["oldValue"] as? ResourceType
        else {
            return
        }
        self.removeFromTypedList(resource, type: oldType)
        self.addToTypedList(resource)
        filtered.removeValue(forKey: oldType)
        filtered.removeValue(forKey: resource.type)
    }
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            !ignoreChanges,
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document,
            let list = filtered[resource.type] ?? resourcesByType[resource.type]
        else {
            return
        }
        let idx = list.firstIndex(of: resource)
        resourcesByType[resource.type]?.sort { $0.id < $1.id }
        filtered.removeValue(forKey: resource.type)
        NotificationCenter.default.post(name: .DirectoryDidUpdateResource, object: self, userInfo: [
            "resource": resource,
            "oldIndex": idx as Any
        ])
    }
    
    var count: Int {
        resourcesByType.reduce(0) { $0 + $1.value.count }
    }
    
    func resources() -> [Resource] {
        return Array(resourcesByType.values.joined())
    }

    func resources(ofType type: ResourceType) -> [Resource] {
        return resourcesByType[type] ?? []
    }
    
    func findResource(type: ResourceType, id: Int) -> Resource? {
        return resourcesByType[type]?.first() { $0.id == id }
    }
    
    func findResource(type: ResourceType, name: String) -> Resource? {
        return resourcesByType[type]?.first() { $0.name == name }
    }

    /// Return an unused resource ID for a new resource of specified type.
    func uniqueID(for type: ResourceType, starting: Int = 128) -> Int {
        // Get a list of used ids (these will be in order)
        let used = self.resources(ofType: type).map(\.id)
        // Find the index of the starting id
        guard var i = used.firstIndex(where: { $0 == starting }) else {
            return starting
        }
        // Keep incrementing the id until we find an unused one
        var id = starting
        let max = document.format.maxID
        while i != used.endIndex && id == used[i] {
            if id == max {
                // WARN: This wraps back to 128 - if there are no unused ids (unlikely) then it will loop infinitely
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
    
    /// Insert an element into the sorted array at the position appropriate for the given comparator function.
    mutating func insert(_ newElement: Element, by comparator: (_ a: Self.Element, _ b: Self.Element) -> Bool) {
        var slice : SubSequence = self[...]
        // Perform a binary search
        while !slice.isEmpty {
            let middle = slice.index(slice.startIndex, offsetBy: slice.count / 2)
            if comparator(slice[middle], newElement) {
                slice = slice[index(after: middle)...]
            } else {
                slice = slice[..<middle]
            }
        }
        self.insert(newElement, at: slice.startIndex)
    }
    
    /// Remove the first occurence of a given element.
    mutating func removeFirst(_ item: Element) {
        if let i = self.firstIndex(of: item) {
            self.remove(at: i)
        }
    }
}
