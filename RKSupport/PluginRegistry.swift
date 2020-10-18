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
    
    /// Return a placeholder name to show for a resource when it has no name.
    public static func placeholderName(for resource: Resource) -> String {
        if resource.id == -16455 {
            // don't bother checking type since there are too many icon types
            return NSLocalizedString("Custom Icon", comment: "")
        }
        
        switch resource.type {
        case "carb":
            if resource.id == 0 {
                return NSLocalizedString("Carbon Identifier", comment: "")
            }
        case "pnot":
            if resource.id == 0 {
                return NSLocalizedString("File Preview", comment: "")
            }
        case "STR ":
            if resource.data.count > 1 {
                do {
                    return try BinaryDataReader(resource.data).readPString()
                } catch {}
            }
            if resource.id == -16396 {
                return NSLocalizedString("Creator Information", comment: "")
            }
        case "STR#":
            if resource.data.count > 3 {
                do {
                    // Read first string at offset 2
                    return try BinaryDataReader(resource.data[2...]).readPString()
                } catch {}
            }
        case "vers":
            if resource.data.count > 8 {
                do {
                    // Read short version string at offset 7
                    return try BinaryDataReader(resource.data[7...]).readPString()
                } catch {}
            }
            if resource.id == 1 {
                return NSLocalizedString("File Version", comment: "")
            } else if resource.id == 2 {
                return NSLocalizedString("Package Version", comment: "")
            }
        default:
            break
        }
        return NSLocalizedString("Untitled Resource", comment: "")
    }
}
