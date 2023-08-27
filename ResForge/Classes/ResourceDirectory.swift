import Foundation
import OrderedCollections
import RFSupport

extension Notification.Name {
    static let DirectoryDidAddResource      = Self("DirectoryDidAddResource")
    static let DirectoryDidRemoveResource   = Self("DirectoryDidRemoveResource")
    static let DirectoryDidUpdateResource   = Self("DirectoryDidUpdateResource")
}

class ResourceDirectory {
    private(set) weak var document: ResourceDocument!
    private(set) var resourceMap: ResourceMap = [:]
    var allTypes: OrderedSet<ResourceType> {
        resourceMap.keys
    }
    private var filtered: ResourceMap = [:]
    var filter = "" {
        didSet {
            filtered.removeAll()
        }
    }
    var sorter: ((_ a: Resource, _ b: Resource) -> Bool)? {
        didSet {
            if sorter != nil || oldValue != nil {
                filtered.removeAll()
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

    /// Reset the directory, replacing all resources.
    func reset(_ newResources: ResourceMap) {
        resourceMap = newResources
        resourceMap.sort { $0.key < $1.key }
        for (type, resources) in resourceMap {
            for resource in resources {
                resource.document = document
                resource.resetState()
            }
            resourceMap[type]?.sort { $0.id < $1.id }
        }
        filtered.removeAll()
    }

    /// Add an array of resources with no notification or undo registration.
    func add(_ resources: [Resource]) {
        for resource in resources {
            self.addToTypedList(resource)
        }
        filtered.removeAll()
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
        if filter.isEmpty && sorter == nil {
            return resourceMap[type] ?? []
        }
        // Maintain a cache of the filtered resources
        if filtered[type] == nil, var resouces = resourceMap[type] {
            if !filter.isEmpty {
                let id = Int(filter)
                resouces = resouces.filter {
                    $0.id == id || $0.name.localizedStandardContains(filter)
                }
            }
            if let sorter {
                resouces.sort(by: sorter)
            }
            filtered[type] = resouces
        }
        return filtered[type] ?? []
    }

    /// Get all types that contain resources matching the current filter.
    func filteredTypes() -> [ResourceType] {
        return filter.isEmpty ? Array(allTypes) : allTypes.filter {
            !self.filteredResources(type: $0).isEmpty
        }
    }

    /// Get the count of resources matching the current filter.
    func filteredCount(type: ResourceType? = nil) -> Int {
        if let type {
            return self.filteredResources(type: type).count
        } else {
            let list = filter.isEmpty ? resourceMap : filtered
            return list.reduce(0) { $0 + $1.value.count }
        }
    }

    private func addToTypedList(_ resource: Resource) {
        resource.document = document
        if resourceMap[resource.type] == nil {
            resourceMap[resource.type] = [resource]
            resourceMap.sort { $0.key < $1.key }
        } else {
            resourceMap[resource.type]?.insert(resource) { $0.id < $1.id }
        }
    }

    private func removeFromTypedList(_ resource: Resource, type: ResourceType? = nil) {
        let type = type ?? resource.type
        resourceMap[type]?.removeFirst(resource)
        if resourceMap[type]?.isEmpty == true {
            resourceMap.removeValue(forKey: type)
        }
        resource.document = nil
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
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document,
            let list = filtered[resource.type] ?? resourceMap[resource.type]
        else {
            return
        }
        let idx = list.firstIndex(of: resource)
        resourceMap[resource.type]?.sort { $0.id < $1.id }
        filtered.removeValue(forKey: resource.type)
        NotificationCenter.default.post(name: .DirectoryDidUpdateResource, object: self, userInfo: [
            "resource": resource,
            "oldIndex": idx as Any
        ])
    }

    var count: Int {
        resourceMap.reduce(0) { $0 + $1.value.count }
    }

    func resources(ofType type: ResourceType) -> [Resource] {
        return resourceMap[type] ?? []
    }

    func findResource(type: ResourceType, id: Int) -> Resource? {
        return resourceMap[type]?.first { $0.id == id }
    }

    func findResource(type: ResourceType, name: String) -> Resource? {
        return resourceMap[type]?.first { $0.name == name }
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
        let max = Swift.type(of: document.format).IDType.max
        while i != used.endIndex && id == used[i] {
            if id == max {
                // WARN: This wraps back to 128 - if there are no unused ids (unlikely) then it will loop infinitely
                id = min(used[0], 128)
                i = 0
            } else {
                id += 1
                i += 1
            }
        }
        return id
    }
}

// Sorted Array extension
extension Array where Element: Equatable {
    /// Insert an element into the sorted array at the position appropriate for the given comparator function.
    mutating func insert(_ newElement: Element, by comparator: (_ a: Self.Element, _ b: Self.Element) -> Bool) {
        var slice: SubSequence = self[...]
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
