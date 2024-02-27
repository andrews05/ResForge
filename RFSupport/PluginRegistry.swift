import Cocoa

public class PluginRegistry {
    public private(set) static var editors: [String: ResourceEditor.Type] = [:]
    public private(set) static var hexEditor: ResourceEditor.Type! = nil
    public private(set) static var previewProviders: [String: PreviewProvider.Type] = [:]
    public private(set) static var exportProviders: [String: ExportProvider.Type] = [:]
    public private(set) static var placeholderProviders: [String: PlaceholderProvider.Type] = [:]
    public private(set) static var templateFilters: [String: TemplateFilter.Type] = [:]

    @objc public static func bundleLoaded(_ notification: Notification) {
        // Iterate over the bundle's loaded classes and register them according to their implemented protocols
        guard let classes = notification.userInfo?[NSLoadedClasses] as? [String] else {
            return
        }
        for className in classes {
            let pluginClass: AnyClass? = NSClassFromString(className)
            if let editor = pluginClass as? ResourceEditor.Type {
                for type in editor.supportedTypes {
                    if type == "*" {
                        Self.hexEditor = editor
                    } else {
                        editors[type] = editor
                    }
                }
            }
            if let previewer = pluginClass as? PreviewProvider.Type {
                for type in previewer.supportedTypes {
                    previewProviders[type] = previewer
                }
            }
            if let exporter = pluginClass as? ExportProvider.Type {
                for type in exporter.supportedTypes {
                    exportProviders[type] = exporter
                }
            }
            if let placeholderer = pluginClass as? PlaceholderProvider.Type {
                for type in placeholderer.supportedTypes {
                    placeholderProviders[type] = placeholderer
                }
            }
            if let filter = pluginClass as? TemplateFilter.Type {
                for type in filter.supportedTypes {
                    templateFilters[type] = filter
                }
            }
        }
    }

    /// Return a placeholder name to show for a resource when it has no name.
    public static func placeholderName(for resource: Resource) -> String {
        if let placeholder = placeholderProviders[resource.typeCode]?.placeholderName(for: resource), !placeholder.isEmpty {
            return placeholder
        }

        if resource.id == -16455 {
            // don't bother checking type since there are too many icon types
            return NSLocalizedString("Custom Icon", comment: "")
        }

        var placeholder = ""
        do {
            switch resource.typeCode {
            case "carb":
                if resource.id == 0 {
                    placeholder = NSLocalizedString("Carbon Identifier", comment: "")
                }
            case "CNTL":
                // Read title at offset 22
                placeholder = try BinaryDataReader(resource.data.dropFirst(22)).readPString()
            case "DLOG":
                // Read title at offset 20
                placeholder = try BinaryDataReader(resource.data.dropFirst(20)).readPString()
            case "MENU", "CMNU", "cmnu":
                // Read title at offset 14
                placeholder = try BinaryDataReader(resource.data.dropFirst(14)).readPString()
                if placeholder == "\u{14}" {
                    placeholder = ""
                }
            case "pnot":
                if resource.id == 0 {
                    placeholder = NSLocalizedString("File Preview", comment: "")
                }
            case "STR ":
                placeholder = try BinaryDataReader(resource.data).readPString()
            case "STR#":
                // Read first string at offset 2
                placeholder = try BinaryDataReader(resource.data.dropFirst(2)).readPString()
            case "TEXT":
                if let string = String(data: resource.data.prefix(100), encoding: .macOSRoman) {
                    placeholder = string
                }
            case "vers":
                // Read short version string at offset 6
                placeholder = try BinaryDataReader(resource.data.dropFirst(6)).readPString()
            case "WIND":
                // Read title at offset 18
                placeholder = try BinaryDataReader(resource.data.dropFirst(18)).readPString()
            default:
                break
            }
        } catch {}

        return placeholder.isEmpty ? NSLocalizedString("Untitled Resource", comment: "") : placeholder
    }
}
