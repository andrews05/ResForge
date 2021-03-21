import Cocoa

public class PluginRegistry {
    public private(set) static var editors: [String: ResourceEditor.Type] = [:]
    public private(set) static var hexEditor: ResourceEditor.Type! = nil
    public private(set) static var templateEditor: TemplateEditor.Type! = nil
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
                if let editor = pluginClass as? TemplateEditor.Type {
                    Self.templateEditor = editor
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
        if let placeholder = placeholderProviders[resource.type]?.placeholderName(for: resource) {
            return placeholder
        }
        
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
        case "STR#":
            if resource.data.count > 3 {
                do {
                    // Read first string at offset 2
                    return try BinaryDataReader(resource.data.dropFirst(2)).readPString()
                } catch {}
            }
        case "TEXT":
            if !resource.data.isEmpty, let string = String(data: resource.data.prefix(100), encoding: .macOSRoman) {
                return string
            }
        case "vers":
            if resource.data.count > 7 {
                do {
                    // Read short version string at offset 6
                    return try BinaryDataReader(resource.data.dropFirst(6)).readPString()
                } catch {}
            }
        default:
            break
        }
        return NSLocalizedString("Untitled Resource", comment: "")
    }
}
