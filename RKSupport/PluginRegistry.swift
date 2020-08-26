import Cocoa

public class PluginRegistry {
    public private(set) static var editors: [String: ResKnifePlugin.Type] = [:]
    public private(set) static var templateEditor: ResKnifePlugin.Type! = nil
    public private(set) static var hexEditor: ResKnifePlugin.Type! = nil
    public private(set) static var previewSizes: [String: Int] = [:]
    private static var icons: [String: NSImage] = [:]
    // Some default icon mappings
    private static let iconTypeMappings = [
        "cfrg": "shlb",
        "SIZE": "shlb",
        "CODE": "s",
        "STR ": "txt",
        "STR#": "txt",
        "plst": "plist",
        "url ": "webloc",
        "NFNT": "ttf",
        "sfnt": "ttf"
    ]
    
    /// Register a plugin bundle as an editor for types defined in its info.plist.
    public static func register(_ plugin: Bundle) {
        guard
            let pluginClass = plugin.principalClass as? ResKnifePlugin.Type,
            let supportedTypes = plugin.infoDictionary?["RKEditedTypes"] as? [String]
        else {
            return
        }
        for type in supportedTypes {
            switch type {
            case "Hexadecimal Editor":
                Self.hexEditor = pluginClass
            case "Template Editor":
                Self.templateEditor = pluginClass
            default:
                editors[type] = pluginClass
                if pluginClass.image != nil {
                    previewSizes[type] = pluginClass.previewSize?(for: type) ?? 64
                }
            }
        }
    }
    
    /// Return an icon representing the resource type.
    public static func icon(for resourceType: String) -> NSImage! {
        if icons[resourceType] == nil {
            // Ask the editor for an icon, falling back to our predefined type mapping or just a default document type
            icons[resourceType] = editors[resourceType]?.icon?(for: resourceType) ?? NSWorkspace.shared.icon(forFileType: iconTypeMappings[resourceType] ?? "")
        }
        return icons[resourceType]
    }
}
