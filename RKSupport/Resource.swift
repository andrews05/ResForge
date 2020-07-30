import Cocoa

public extension Notification.Name {
    static let ResourceWillChange           = Self("ResourceWillChangeNotification")
    static let ResourceNameWillChange       = Self("ResourceNameWillChangeNotification")
    static let ResourceTypeWillChange       = Self("ResourceTypeWillChangeNotification")
    static let ResourceIDWillChange         = Self("ResourceIDWillChangeNotification")
    static let ResourceAttributesWillChange = Self("ResourceAttributesWillChangeNotification")
    static let ResourceDataWillChange       = Self("ResourceDataWillChangeNotification")
    
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
        willSet {
            NotificationCenter.default.post(name: .ResourceTypeWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var resID: Int {
        willSet {
            NotificationCenter.default.post(name: .ResourceIDWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceIDDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var name: String {
        willSet {
            NotificationCenter.default.post(name: .ResourceNameWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceNameDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    public var attributes: ResAttributes {
        willSet {
            NotificationCenter.default.post(name: .ResourceAttributesWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceAttributesDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var data: Data {
        willSet {
            NotificationCenter.default.post(name: .ResourceDataWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceDataDidChange, object: self, userInfo: ["oldValue":oldValue])
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var size: Int {
        return data.count
    }
    
    @objc public var document: NSDocument!
    @objc public var manager: ResKnifePluginManager!
    
    @objc public var defaultWindowTitle: String {
        let title = document.displayName.appending(": \(type) \(resID)")
        return name.count > 0 ? title.appending(" '\(name)'") : title
    }
    
    
    @objc public init(type: String, id: Int, name: String = "", attributes: Int = 0, data: Data = Data()) {
        self.type = type
        self.resID = id
        self.name = name
        self.attributes = ResAttributes(rawValue: attributes)
        self.data = data
    }

    // MARK: - Pasteboard functions
    
    public static var supportsSecureCoding = true
    
    public required init?(coder: NSCoder) {
        type = coder.decodeObject(of: NSString.self, forKey: "type")! as String
        resID = coder.decodeInteger(forKey: "id")
        name = coder.decodeObject(of: NSString.self, forKey: "name")! as String
        attributes = ResAttributes(rawValue: coder.decodeInteger(forKey: "attributes"))
        data = coder.decodeObject(of: NSData.self, forKey: "data")! as Data
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(type, forKey: "type")
        coder.encode(resID, forKey: "id")
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
