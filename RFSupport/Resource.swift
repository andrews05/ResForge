import Cocoa

public extension Notification.Name {
    static let ResourceDidChange            = Self("ResourceDidChange")
    static let ResourceNameDidChange        = Self("ResourceNameDidChange")
    static let ResourceTypeDidChange        = Self("ResourceTypeDidChange")
    static let ResourceIDDidChange          = Self("ResourceIDDidChange")
    static let ResourceDataDidChange        = Self("ResourceDataDidChange")
}

public extension NSPasteboard.PasteboardType {
    static let RKResource = Self("com.resforge.resource")
}

public struct ResourceType: Hashable, CustomStringConvertible {
    public var code: String
    public var attributes: [String: String]
    public var description: String {
        attributes.reduce(code, { "\($0):\($1.0)=\($1.1)" })
    }
    public var attributesDisplay: String {
        attributes.map({ "\($0.0)=\($0.1)" }).joined(separator: ", ")
    }
    
    public init(_ code: String, _ attributes: [String: String] = [:]) {
        self.code = code
        self.attributes = attributes
    }
}

public class Resource: NSObject, NSSecureCoding, NSPasteboardWriting, NSPasteboardReading {
    public weak var document: NSDocument!
    public var attributes = 0 // Not supported
    public private(set) var type: ResourceType
    private var _preview: NSImage?

    @objc dynamic public var typeCode: String {
        get {
            type.code
        }
        set {
            let oldValue = type
            if oldValue.code != newValue {
                type.code = newValue
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Type", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.typeCode = oldValue.code })
            }
        }
    }
    
    @objc public var typeAttributes: [String: String] {
        get {
            type.attributes
        }
        set {
            let oldValue = type
            if oldValue.attributes != newValue {
                type.attributes = newValue
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Type Attributes", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.typeAttributes = oldValue.attributes })
            }
        }
    }
    
    @objc dynamic public var id: Int {
        didSet {
            if id != oldValue {
                NotificationCenter.default.post(name: .ResourceIDDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change ID", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.id = oldValue })
            }
        }
    }
    
    @objc dynamic public var name: String {
        didSet {
            if name != oldValue {
                NotificationCenter.default.post(name: .ResourceNameDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Name", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.name = oldValue })
            }
        }
    }
    
    @objc public var data: Data {
        didSet {
            _preview = nil
            NotificationCenter.default.post(name: .ResourceDataDidChange, object: self)
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
            document?.updateChangeCount(.changeDone)
        }
    }
    
    public var defaultWindowTitle: String {
        if let document = document {
            let title = document.displayName.appending(": \(typeCode) \(id)")
            return name.isEmpty ? title : title.appending(" '\(name)'")
        }
        return name
    }
    
    public init(type: ResourceType, id: Int, name: String = "", data: Data = Data()) {
        self.type = type
        self.id = id
        self.name = name
        self.data = data
    }
    
    @objc public init(typeCode: String, typeAttributes: [String: String], id: Int, name: String, data: Data) {
        self.type = ResourceType(typeCode, typeAttributes)
        self.id = id
        self.name = name
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

    // MARK: - Pasteboard functions
    
    public static var supportsSecureCoding = true
    
    public required init?(coder: NSCoder) {
        let typeCode = coder.decodeObject(of: NSString.self, forKey: "typeCode")! as String
        let typeAttributes = coder.decodeObject(of: NSDictionary.self, forKey: "typeAttributes")! as! [String:String]
        type = ResourceType(typeCode, typeAttributes)
        id = coder.decodeInteger(forKey: "id")
        name = coder.decodeObject(of: NSString.self, forKey: "name")! as String
        attributes = coder.decodeInteger(forKey: "attributes")
        data = coder.decodeObject(of: NSData.self, forKey: "data")! as Data
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(typeCode, forKey: "typeCode")
        coder.encode(typeAttributes, forKey: "typeAttributes")
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(attributes, forKey: "attributes")
        coder.encode(data, forKey: "data")
    }
    
    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.RKResource]
    }
    
    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
    public static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [.RKResource]
    }
    
    public static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        return .asKeyedArchive
    }
    
    public required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        return nil
    }
}
