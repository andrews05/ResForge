import Foundation

class EditorRegistry: NSObject {
    public static let `default` = EditorRegistry()
    
    private var registry: [String: ResKnifePlugin.Type] = [:]
    
    @objc public static func defaultRegistry() -> EditorRegistry {
        return Self.default
    }
    
    @objc public func editor(for type: String) -> ResKnifePlugin.Type? {
        return registry[type]
    }
    
    public func scanForPlugins() {
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
            guard item.pathExtension == "plugin" else {
                continue
            }
            let plugin = Bundle(url: item)
            guard
                let pluginClass = plugin?.principalClass as? ResKnifePlugin.Type,
                let info = plugin?.infoDictionary,
                let supportedTypes = info["RKEditedTypes"] as? Array<String>
            else {
                continue
            }
            RKSupportResourceRegistry.scanForSupportResources(in: plugin)
            for type in supportedTypes {
                registry[type] = pluginClass
            }
        }
    }
}
