import AppKit

public extension Notification.Name {
    /// Resource id, name or data changed. This is not sent for type or attribute changes.
    static let ResourceDidChange            = Self("ResourceDidChange")
    static let ResourceNameDidChange        = Self("ResourceNameDidChange")
    static let ResourceTypeDidChange        = Self("ResourceTypeDidChange")
    static let ResourceIDDidChange          = Self("ResourceIDDidChange")
    static let ResourceAttributesDidChange  = Self("ResourceAttributesDidChange")
    static let ResourceDataDidChange        = Self("ResourceDataDidChange")

    static let DocumentDidAddResource       = Self("DocumentDidAddResource")
    static let DocumentDidRemoveResource    = Self("DocumentDidRemoveResource")
}

public extension NSPasteboard.PasteboardType {
    static let RFResource = Self("com.resforge.resource")
}

public struct ResourceType: Hashable, Comparable, CustomStringConvertible {
    public static let Template = Self("TMPL")
    public static let BasicTemplate = Self("TMPB")

    public var code: String
    public var attributes: [String: String]
    public var description: String {
        return attributes.isEmpty ? code : "\(code) + \(attributesDisplay)"
    }
    public var attributesDisplay: String {
        attributes.map({ "\($0.0) = \($0.1)" }).joined(separator: ", ")
    }

    public init(_ code: String, _ attributes: [String: String] = [:]) {
        self.code = code
        self.attributes = attributes
    }

    public static func < (lhs: ResourceType, rhs: ResourceType) -> Bool {
        let compare = lhs.code.localizedCompare(rhs.code)
        return compare == .orderedSame ? lhs.attributes.count < rhs.attributes.count : compare == .orderedAscending
    }
}

public struct ResAttributes: OptionSet, Hashable {
    public let rawValue: Int
    public static let changed   = Self(rawValue: 2)
    public static let preload   = Self(rawValue: 4)
    public static let protected = Self(rawValue: 8)
    public static let locked    = Self(rawValue: 16)
    public static let purgeable = Self(rawValue: 32)
    public static let sysHeap   = Self(rawValue: 64)
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public class Resource: NSObject, NSSecureCoding, NSPasteboardWriting, NSPasteboardReading {
    // The resource state tracks original values for the resource's properties.
    // It is used to determine whether the resource is new/modified/etc.
    public struct State {
        public var type: ResourceType?
        public var id: Int?
        public var name: String?
        public var attributes: ResAttributes?
        public var data: Data?
        public var revision: Int?
        public var disableTracking = false
    }

    public weak var document: NSDocument!
    public private(set) var type: ResourceType
    private var _preview: NSImage?
    public var _state = State()

    @objc dynamic public var typeCode: String {
        get {
            type.code
        }
        set {
            let oldValue = type
            if let document, oldValue.code != newValue {
                type.code = newValue
                if !_state.disableTracking && _state.revision != nil && _state.type == nil {
                    _state.type = oldValue
                }
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue": oldValue])
                document.undoManager?.setActionName(NSLocalizedString("Change Type", comment: ""))
                document.undoManager?.registerUndo(withTarget: self) { $0.typeCode = oldValue.code }
            }
        }
    }

    @objc public var typeAttributes: [String: String] {
        get {
            type.attributes
        }
        set {
            let oldValue = type
            if let document, oldValue.attributes != newValue {
                type.attributes = newValue
                if !_state.disableTracking && _state.revision != nil && _state.type == nil {
                    _state.type = oldValue
                }
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue": oldValue])
                document.undoManager?.setActionName(NSLocalizedString("Change Type Attributes", comment: ""))
                document.undoManager?.registerUndo(withTarget: self) { $0.typeAttributes = oldValue.attributes }
            }
        }
    }

    @objc dynamic public var id: Int {
        didSet {
            if let document, id != oldValue {
                if !_state.disableTracking && _state.revision != nil && _state.id == nil {
                    _state.id = oldValue
                }
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                NotificationCenter.default.post(name: .ResourceIDDidChange, object: self, userInfo: ["oldValue": oldValue])
                document.undoManager?.setActionName(NSLocalizedString("Change ID", comment: ""))
                document.undoManager?.registerUndo(withTarget: self) { $0.id = oldValue }
            }
        }
    }

    @objc dynamic public var name: String {
        didSet {
            if let document, name != oldValue {
                if !_state.disableTracking && _state.revision != nil && _state.name == nil {
                    _state.name = oldValue
                }
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                NotificationCenter.default.post(name: .ResourceNameDidChange, object: self, userInfo: ["oldValue": oldValue])
                document.undoManager?.setActionName(NSLocalizedString("Change Name", comment: ""))
                document.undoManager?.registerUndo(withTarget: self) { $0.name = oldValue }
            }
        }
    }

    public var attributes: ResAttributes {
        // ResAttributes is not compatible with objc so we need to manually trigger change events
        willSet {
            self.willChangeValue(forKey: "attributes")
        }
        didSet {
            if let document, attributes != oldValue {
                if !_state.disableTracking && _state.revision != nil && _state.attributes == nil {
                    _state.attributes = oldValue
                }
                NotificationCenter.default.post(name: .ResourceAttributesDidChange, object: self, userInfo: ["oldValue": oldValue])
                document.undoManager?.setActionName(NSLocalizedString("Change Attributes", comment: ""))
                document.undoManager?.registerUndo(withTarget: self) { $0.attributes = oldValue }
            }
            self.didChangeValue(forKey: "attributes")
        }
    }

    @objc public var data: Data {
        didSet {
            _preview = nil
            if let document {
                if !_state.disableTracking && _state.revision != nil && _state.data == nil {
                    _state.data = oldValue
                }
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                NotificationCenter.default.post(name: .ResourceDataDidChange, object: self)
                document.updateChangeCount(.changeDone)
            }
        }
    }

    public var defaultWindowTitle: String {
        let title = "\(typeCode) \(id)"
        return name.isEmpty ? title : title.appending(" - \(name)")
    }

    public init(type: ResourceType, id: Int, name: String = "", attributes: Int = 0, data: Data = Data()) {
        self.type = type
        self.id = id
        self.name = name
        self.attributes = ResAttributes(rawValue: attributes)
        self.data = data
    }

    /// Asynchonously fetch the resource's preview image. The image will be initially loaded on a background thread and cached for future use.
    public func preview(_ callback: @escaping (NSImage?) -> Void) {
        if _preview == nil && !data.isEmpty {
            if let loader = PluginRegistry.previewProviders[typeCode]?.image {
                DispatchQueue.global().async {
                    // If we fail to load a preview, show an x image instead - this prevents repeatedly trying to parse bad data
                    self._preview = loader(self) ?? NSImage(named: NSImage.stopProgressTemplateName)
                    DispatchQueue.main.async {
                        callback(self._preview)
                    }
                }
                return
            } else {
                _preview = NSImage(named: NSImage.stopProgressTemplateName)
            }
        }
        callback(self._preview)
    }

    /// Return a placeholder name to show for when the resource has no name.
    public func placeholderName() -> String {
        return PluginRegistry.placeholderName(for: self)
    }

    /// Return a filename and extension to use when exporting the resource with the given ExportProvider.
    public func filenameForExport(using exporter: ExportProvider.Type?) -> (name: String, ext: String) {
        var filename = name.replacingOccurrences(of: "/", with: ":")
        if filename == "" {
            filename = "\(typeCode) \(id)"
        }
        let ext = exporter?.filenameExtension(for: typeCode) ?? typeCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return (filename, ext)
    }

    // MARK: - Pasteboard functions

    public static var supportsSecureCoding = true

    public required init?(coder: NSCoder) {
        guard
            let typeCode = coder.decodeObject(of: NSString.self, forKey: "typeCode") as String?,
            let typeAttributes = coder.decodeObject(of: [NSDictionary.self, NSString.self], forKey: "typeAttributes") as? [String: String],
            let name = coder.decodeObject(of: NSString.self, forKey: "name") as String?,
            let data = coder.decodeObject(of: NSData.self, forKey: "data") as Data?
        else {
            return nil
        }
        type = ResourceType(typeCode, typeAttributes)
        id = coder.decodeInteger(forKey: "id")
        self.name = name
        attributes = ResAttributes(rawValue: coder.decodeInteger(forKey: "attributes"))
        self.data = data
    }

    public func encode(with coder: NSCoder) {
        coder.encode(typeCode, forKey: "typeCode")
        coder.encode(typeAttributes, forKey: "typeAttributes")
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(attributes.rawValue, forKey: "attributes")
        coder.encode(data, forKey: "data")
    }

    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.RFResource]
    }

    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        return try? NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
    }

    public static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.RFResource]
    }

    public static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        return .asKeyedArchive
    }

    public required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        return nil
    }
}
