import Foundation
import RKSupport

class SupportRegistry {
    static let collection = ResourceCollection()
    
    static func scanForResources() {
        Self.scanForResources(in: Bundle.main)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        for url in appSupport {
            let items: [URL]
            do {
                items = try FileManager.default.contentsOfDirectory(at: url.appendingPathComponent("ResKnife/Support Resources"), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
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
        guard let items = bundle.urls(forResourcesWithExtension: "rsrc", subdirectory: "Support Resources") else {
            return
        }
        for item in items {
            Self.load(resourceFile: item)
        }
    }
    
    private static func load(resourceFile: URL) {
        do {
            let resources = try ResourceFile.read(from: resourceFile, format: nil)
            collection.add(resources)
        } catch {}
    }
}
