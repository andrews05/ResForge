/*
 This is a registry where all our resource-editor plugins are looked
 up and entered in a list, so you can ask for the editor for a specific
 resource type and it is returned immediately. This registry reads the
 types a plugin handles from their info.plist.
 */

import Foundation

class EditorRegistry: NSObject {
    static let `default` = EditorRegistry()
    
    private var registry: [String: ResKnifePlugin.Type] = [:]
    
    @objc static func defaultRegistry() -> EditorRegistry {
        return Self.default
    }
    
    @objc func editor(for type: String) -> ResKnifePlugin.Type? {
        return registry[type]
    }
    
    func scanForPlugins() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        for url in appSupport {
            self.scan(folder: url.appendingPathComponent("ResKnife/Plugins"))
        }
        if let plugins = Bundle.main.builtInPlugInsURL {
            self.scan(folder: plugins)
        }
    }
    
    private func scan(folder: URL) {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            return
        }
        for item in items {
            guard
                item.pathExtension == "plugin",
                let plugin = Bundle(url: item),
                let pluginClass = plugin.principalClass as? ResKnifePlugin.Type,
                let supportedTypes = plugin.infoDictionary?["RKEditedTypes"] as? Array<String>
            else {
                continue
            }
            SupportResourceRegistry.scanForResources(in: plugin)
            for type in supportedTypes {
                registry[type] = pluginClass
            }
        }
    }
}
