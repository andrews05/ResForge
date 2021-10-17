import Foundation
import RFSupport

class SupportRegistry: ResourceDirectory {
    static let directory = SupportRegistry()
    
    // The support registry is where most templates are found and since the directory doesn't
    // change after app launch we can keep an index of resources by name for faster template lookups
    private var nameIndex: [ResourceType: [String: Resource]] = [:]
    
    override func findResource(type: ResourceType, name: String) -> Resource? {
        if nameIndex[type] == nil {
            guard let resources = resourcesByType[type] else {
                return nil
            }
            nameIndex[type] = resources.reduce(into: [:]) {
                $0[$1.name] = $1
            }
        }
        return nameIndex[type]?[name]
    }
    
    static func scanForResources() {
        Self.scanForResources(in: Bundle.main)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        for url in appSupport {
            let items: [URL]
            do {
                items = try FileManager.default.contentsOfDirectory(at: url.appendingPathComponent("ResForge/Support Resources"), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            } catch {
                continue
            }
            for item in items {
                if item.pathExtension == "rsrc" {
                    Self.load(resourceFile: item)
                }
            }
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
            let resources = try ResourceFile.read(from: resourceFile, format: nil)
            directory.add(resources)
        } catch {}
    }
}
