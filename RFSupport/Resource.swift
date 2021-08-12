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

public class Resource: NSObject, NSSecureCoding, NSPasteboardWriting, NSPasteboardReading {
    public var attributes = 0 // Not supported
    
    @objc dynamic public var type: String {
        didSet {
            if type != oldValue {
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Type", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.type = oldValue })
            }
        }
    }
    
    @objc public var typeAttributes: [String: String] {
        didSet {
            if typeAttributes != oldValue {
//                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self, userInfo: ["oldValue":oldValue])
                NotificationCenter.default.post(name: .ResourceDidChange, object: self)
                document?.undoManager?.setActionName(NSLocalizedString("Change Type Attributes", comment: ""))
                document?.undoManager?.registerUndo(withTarget: self, handler: { $0.typeAttributes = oldValue })
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
    
    public weak var document: NSDocument!
    private var _preview: NSImage?
    
    public var defaultWindowTitle: String {
        if let document = document {
            let title = document.displayName.appending(": \(type) \(id)")
            return name.isEmpty ? title : title.appending(" '\(name)'")
        }
        return name
    }
    
    @objc public init(type: String, id: Int, name: String = "", data: Data = Data(), typeAttributes: [String: String] = [:]) {
        self.type = type
        self.typeAttributes = typeAttributes
        self.id = id
        self.name = name
        self.data = data
    }
    
    /// Asynchonously fetch the resource's preview image. The image will be initially loaded on a background thread and cached for future use.
    public func preview(_ callback: @escaping (NSImage?) -> Void) {
        if _preview == nil && !data.isEmpty {
            if let loader = PluginRegistry.previewProviders[type]?.image {
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
        type = coder.decodeObject(of: NSString.self, forKey: "type")! as String
        typeAttributes = coder.decodeObject(of: NSDictionary.self, forKey: "typeAttributes")! as! [String:String]
        id = coder.decodeInteger(forKey: "id")
        name = coder.decodeObject(of: NSString.self, forKey: "name")! as String
        attributes = coder.decodeInteger(forKey: "attributes")
        data = coder.decodeObject(of: NSData.self, forKey: "data")! as Data
    }
    
    public func encode(with coder: NSCoder) {
        coder.encode(type, forKey: "type")
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
