import AppKit

public class PluginRegistry {
    public private(set) static var editors: [String: ResourceEditor.Type] = [:]
    public private(set) static var hexEditor: ResourceEditor.Type! = nil
    public private(set) static var previewProviders: [String: PreviewProvider.Type] = [:]
    public private(set) static var exportProviders: [String: ExportProvider.Type] = [:]
    public private(set) static var placeholderProviders: [String: PlaceholderProvider.Type] = [:]
    public private(set) static var templateFilters: [String: TemplateFilter.Type] = [:]
    public private(set) static var typeIcons: [String: String] = [:]

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
            if let provider = pluginClass as? PreviewProvider.Type {
                for type in provider.supportedTypes {
                    previewProviders[type] = provider
                }
            }
            if let provider = pluginClass as? ExportProvider.Type {
                for type in provider.supportedTypes {
                    exportProviders[type] = provider
                }
            }
            if let provider = pluginClass as? PlaceholderProvider.Type {
                for type in provider.supportedTypes {
                    placeholderProviders[type] = provider
                }
            }
            if let provider = pluginClass as? TypeIconProvider.Type {
                for (type, icon) in provider.typeIcons {
                    typeIcons[type] = icon
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
            case "utxt":
                if let string = String(data: resource.data.prefix(100), encoding: .utf8) {
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

    public static func icon(for type: ResourceType) -> NSImage? {
        guard #available(macOS 11, *) else {
            return nil
        }

        let icon = if let icon = typeIcons[type.code] {
            icon
        } else {
            switch type.code {
            case "ALRT":
                "exclamationmark.bubble"
            case "cicn", "ICON", "SICN":
                "exclamationmark.triangle"
            case "clut", "pltt":
                "paintpalette"
            case "crsr", "CURS":
                "hand.point.up"
            case "DLOG":
                "note.text"
            case "DITL":
                "square.fill.text.grid.1x2"
            case "GIFf", "jpeg", "PICT", "PNG ", "PNGf":
                "photo"
            case "ICN#", "icl4", "icl8", "icm#", "icm4", "icm8", "ics#", "ics4", "ics8", "kcs#", "kcs4", "kcs8":
                "doc.circle"
            case "MENU":
                "filemenu.and.selection"
            case "PAT ", "ppat":
                "squareshape.dashed.squareshape"
            case "PAT#", "ppt#":
                "square.3.stack.3d"
            case "snd ":
                "speaker.wave.2"
            case "STR ":
                "textformat.abc"
            case "STR#":
                "list.number"
            case "TMPB", "TMPL":
                "list.bullet.rectangle"
            case "WIND":
                "macwindow"
            default:
                "doc"
            }
        }

        if icon.count == 1 {
            // Render a single character as an image
            return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                (icon as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
                return true
            }
        }
        // Create system symbol image, falling back to doc if given symbol is not available
        return NSImage(systemSymbolName: icon, accessibilityDescription: nil) ??
            NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
    }
}
