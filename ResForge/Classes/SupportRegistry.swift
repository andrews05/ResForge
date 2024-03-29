import Foundation
import RFSupport

class SupportRegistry {
    static let directory = SupportRegistry()

    private(set) var resourceMap: [ResourceType: [Resource]] = [:]
    // The support registry is where most templates are found and since the directory doesn't
    // change after app launch we can keep an index of resources by name for faster template lookups
    private var nameIndex: [ResourceType: [String: Resource]] = [:]

    func resources(ofType type: ResourceType) -> [Resource] {
        return resourceMap[type] ?? []
    }

    func findResource(type: ResourceType, id: Int) -> Resource? {
        return resourceMap[type]?.first { $0.id == id }
    }

    func findResource(type: ResourceType, name: String) -> Resource? {
        if nameIndex[type] == nil {
            guard let resources = resourceMap[type] else {
                return nil
            }
            nameIndex[type] = resources.reduce(into: [String: Resource]()) { map, resource in
                // Make sure later resources do not override earlier ones
                if map[resource.name] == nil {
                    map[resource.name] = resource
                }
            }
        }
        return nameIndex[type]?[name]
    }

    static func scanForResources(in folder: URL) {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            return
        }
        for item in items.sorted(by: { $0.path.localizedStandardCompare($1.path) == .orderedAscending }) {
            Self.load(resourceFile: item)
        }
    }

    static func scanForResources(in bundle: Bundle) {
        guard let items = bundle.urls(forResourcesWithExtension: "rsrc", subdirectory: nil) else {
            return
        }
        for item in items {
            Self.load(resourceFile: item)
        }
    }

    private static func load(resourceFile: URL) {
        do {
            let data = try Data(contentsOf: resourceFile)
            let format = try ResourceFormat.from(data: data)
            let resourceMap = try format.read(data)
            // Files loaded later should have precendence over files loaded earlier. This means their
            // resources should come first in the master list. To achieve this we sort the type lists
            // by id, then prepend them to the master list.
            for (rType, resources) in resourceMap {
                let resources = resources.sorted { $0.id < $1.id }
                directory.resourceMap[rType, default: []].insert(contentsOf: resources, at: 0)
            }
        } catch {}
    }
}
