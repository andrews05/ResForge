import Cocoa

public extension Notification.Name {
    static let ResourceDidChange            = Self("ResourceDidChangeNotification")
    static let ResourceNameDidChange        = Self("ResourceNameDidChangeNotification")
    static let ResourceTypeDidChange        = Self("ResourceTypeDidChangeNotification")
    static let ResourceIDDidChange          = Self("ResourceIDDidChangeNotification")
    static let ResourceAttributesDidChange  = Self("ResourceAttributesDidChangeNotification")
    static let ResourceDataDidChange        = Self("ResourceDataDidChangeNotification")
}

public extension NSPasteboard.PasteboardType {
    static let RKResource = Self(rawValue: "com.nickshanks.resknife.resource")
}

public struct ResAttributes: OptionSet {
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
            NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
            self.document?.undoManager?.setActionName(NSLocalizedString("Change Type", comment: ""))
            self.document?.undoManager?.registerUndo(withTarget: self, handler: { $0.type = oldValue })
        }
    }
    
    @objc public var id: Int {
        didSet {
            NotificationCenter.default.post(name: .ResourceIDDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
            self.document?.undoManager?.setActionName(NSLocalizedString("Change ID", comment: ""))
            self.document?.undoManager?.registerUndo(withTarget: self, handler: { $0.id = oldValue })
        }
    }
    
    @objc public var name: String {
        didSet {
            NotificationCenter.default.post(name: .ResourceNameDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
            self.document?.undoManager?.setActionName(NSLocalizedString("Change Name", comment: ""))
            self.document?.undoManager?.registerUndo(withTarget: self, handler: { $0.name = oldValue })
        }
    }
    
    public var attributes: ResAttributes {
        didSet {
            NotificationCenter.default.post(name: .ResourceAttributesDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
            self.document?.undoManager?.setActionName(NSLocalizedString("Change Attributes", comment: ""))
            self.document?.undoManager?.registerUndo(withTarget: self, handler: { $0.attributes = oldValue })
        }
    }
    
    @objc public var data: Data {
        didSet {
            NotificationCenter.default.post(name: .ResourceDataDidChange, object: self)
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
            self.document?.updateChangeCount(.changeDone)
        }
    }
    
    @objc public var document: NSDocument!
    @objc public var manager: ResKnifePluginManager!
    
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
