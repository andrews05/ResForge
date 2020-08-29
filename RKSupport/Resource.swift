import Cocoa

public extension Notification.Name {
    static let ResourceDidChange            = Self("ResourceDidChange")
    static let ResourceNameDidChange        = Self("ResourceNameDidChange")
    static let ResourceTypeDidChange        = Self("ResourceTypeDidChange")
    static let ResourceIDDidChange          = Self("ResourceIDDidChange")
    static let ResourceAttributesDidChange  = Self("ResourceAttributesDidChange")
    static let ResourceDataDidChange        = Self("ResourceDataDidChange")
}

public extension NSPasteboard.PasteboardType {
    static let RKResource = Self(rawValue: "com.nickshanks.resknife.resource")
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
    @objc public var type: String {
        didSet {
            if type != oldValue {
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Type", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.type = oldValue })
            }
        }
    }
    
    @objc public var id: Int {
        didSet {
            if id != oldValue {
                NotificationCenter.default.post(name: .ResourceIDDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change ID", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.id = oldValue })
            }
        }
    }
    
    @objc public var name: String {
        didSet {
            if name != oldValue {
                NotificationCenter.default.post(name: .ResourceNameDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Name", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.name = oldValue })
            }
        }
    }
    
    public var attributes: ResAttributes {
        didSet {
            if attributes != oldValue {
                NotificationCenter.default.post(name: .ResourceAttributesDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Attributes", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.attributes = oldValue })
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
    
    @objc public weak var document: NSDocument!
    @objc public weak var manager: ResKnifePluginManager! // This isn't set until the resource is opened in an editor
    private var _preview: NSImage?
    
    @objc public var defaultWindowTitle: String {
        if let document = document {
            let title = document.displayName.appending(": \(type) \(id)")
            return name.count > 0 ? title.appending(" '\(name)'") : title
        }
        return name
    }
    
    @objc public init(type: String, id: Int, name: String = "", attributes: Int = 0, data: Data = Data()) {
        self.type = type
        self.id = id
        self.name = name
        self.attributes = ResAttributes(rawValue: attributes)
        self.data = data
    }
    
    /// Asynchonously fetch the resource's preview image. The image will be initially loaded on a background thread and cached for future use.
    public func preview(_ callback: @escaping (NSImage?) -> Void) {
        if _preview == nil && data.count > 0 {
            if let loader = PluginRegistry.editors[type]?.image {
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

    // MARK: - Pasteboard functions
    
    public static var supportsSecureCoding = true
    
    public required init?(coder: NSCoder) {
        type = coder.decodeObject(of: NSString.self, forKey: "type")! as String
        id = coder.decodeInteger(forKey: "id")
        name = coder.decodeObject(of: NSString.self, forKey: "name")! as String
        attributes = ResAttributes(rawValue: coder.decodeInteger(forKey: "attributes"))
        data = coder.decodeObject(of: NSData.self, forKey: "data")! as Data
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(type, forKey: "type")
        coder.encode(id, forKey: "id")
        coder.encode(name, forKey: "name")
        coder.encode(attributes.rawValue, forKey: "attributes")
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
