import Cocoa

public extension Notification.Name {
    static let ResourceWillChange           = Notification.Name("ResourceWillChangeNotification")
    static let ResourceNameWillChange       = Notification.Name("ResourceNameWillChangeNotification")
    static let ResourceTypeWillChange       = Notification.Name("ResourceTypeWillChangeNotification")
    static let ResourceIDWillChange         = Notification.Name("ResourceIDWillChangeNotification")
    static let ResourceAttributesWillChange = Notification.Name("ResourceAttributesWillChangeNotification")
    static let ResourceDataWillChange       = Notification.Name("ResourceDataWillChangeNotification")
    
    static let ResourceDidChange            = Notification.Name("ResourceDidChangeNotification")
    static let ResourceNameDidChange        = Notification.Name("ResourceNameDidChangeNotification")
    static let ResourceTypeDidChange        = Notification.Name("ResourceTypeDidChangeNotification")
    static let ResourceIDDidChange          = Notification.Name("ResourceIDDidChangeNotification")
    static let ResourceAttributesDidChange  = Notification.Name("ResourceAttributesDidChangeNotification")
    static let ResourceDataDidChange        = Notification.Name("ResourceDataDidChangeNotification")
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

public class Resource: NSObject, NSCoding {
    @objc public var type: String {
        willSet {
            NotificationCenter.default.post(name: .ResourceTypeWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self)
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var resID: Int {
        willSet {
            NotificationCenter.default.post(name: .ResourceIDWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceIDDidChange, object: self)
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var name: String {
        willSet {
            NotificationCenter.default.post(name: .ResourceNameWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceNameDidChange, object: self)
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    public var attributes: ResAttributes {
        willSet {
            NotificationCenter.default.post(name: .ResourceAttributesWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceAttributesDidChange, object: self)
            NotificationCenter.default.post(name: .ResourceDidChange, object: self)
        }
    }
    
    @objc public var data: Data {
        willSet {
            NotificationCenter.default.post(name: .ResourceDataWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceDataDidChange, object: self)
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

    /* encoding */
    
    public required init?(coder: NSCoder) {
        type = coder.decodeObject() as! String
        resID = coder.decodeObject() as! Int
        name = coder.decodeObject() as! String
        attributes = ResAttributes(rawValue: coder.decodeObject() as! Int)
        data = coder.decodeData()!
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(type)
        coder.encode(resID)
        coder.encode(name)
        coder.encode(attributes.rawValue)
        coder.encode(data)
    }
}
