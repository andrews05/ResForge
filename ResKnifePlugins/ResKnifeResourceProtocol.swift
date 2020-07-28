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

@objc public protocol ResKnifeResource {
    @objc var name: String { get set }
    @objc var type: String { get set }
    @objc var resID: Int { get set }
    //@objc var attributes: Int16 { get set }
    @objc var data: Data { get set }
    @objc var document: NSDocument! { get }
    @objc var defaultWindowTitle: String { get }
    
    @objc func open()
}
