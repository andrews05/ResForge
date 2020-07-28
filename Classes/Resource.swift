import Foundation
import ResKnifePlugins

struct ResAttributes: OptionSet {
    let rawValue: Int
    static let resChanged   = Self(rawValue: 2)
    static let resPreload   = Self(rawValue: 4)
    static let resProtected = Self(rawValue: 8)
    static let resLocked    = Self(rawValue: 16)
    static let resPurgeable = Self(rawValue: 32)
    static let resSysHeap   = Self(rawValue: 64)
}

enum ResourceError: LocalizedError {
    case conflict(String, Int)
    var errorDescription: String? {
        switch self {
        case .conflict(let type, let id):
            return String(format: NSLocalizedString("A resource of type '%@' with ID %d already exists.", comment: ""), type, id)
        }
    }
}

class Resource: NSObject, NSCoding, ResKnifeResource {
    private var _type: String
    @objc var type: String {
        get {
            _type
        }
        set {
            if self.checkConflict(type: newValue, id: _id) {
                NotificationCenter.default.post(name: .ResourceTypeWillChange, object: self)
                _type = newValue
                NotificationCenter.default.post(name: .ResourceTypeDidChange, object: self)
            }
        }
    }
    
    private var _id: Int
    @objc var resID: Int {
        get {
            _id
        }
        set {
            if self.checkConflict(type: _type, id: newValue) {
                NotificationCenter.default.post(name: .ResourceIDWillChange, object: self)
                _id = newValue
                NotificationCenter.default.post(name: .ResourceIDDidChange, object: self)
            }
        }
    }
    
    @objc var name = "" {
        willSet {
            NotificationCenter.default.post(name: .ResourceNameWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceNameDidChange, object: self)
        }
    }
    
    var attributes: ResAttributes {
        willSet {
            NotificationCenter.default.post(name: .ResourceAttributesWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceAttributesDidChange, object: self)
        }
    }
    
    @objc var data = Data() {
        willSet {
            NotificationCenter.default.post(name: .ResourceDataWillChange, object: self)
        }
        didSet {
            NotificationCenter.default.post(name: .ResourceDataDidChange, object: self)
        }
    }
    
    @objc var size: Int {
        return data.count
    }
    
    private var _document: ResourceDocument!
    @objc var document: NSDocument! {
        get {
            _document
        }
        set {
            _document = newValue as? ResourceDocument
        }
    }
    
    var defaultWindowTitle: String {
        let title = document.displayName.appending(": \(type) \(resID)")
        return name.count > 0 ? title.appending(" '\(name)'") : title
    }
    
    
    @objc init(type: String, id: Int, name: String = "", attributes: Int = 0, data: Data = Data()) {
        self._type = type
        self._id = id
        self.name = name
        self.attributes = ResAttributes(rawValue: attributes)
        self.data = data
    }
    
    
    func open() {
        _document.openResource(usingEditor: self)
    }
    
    private func checkConflict(type: String, id: Int) -> Bool {
        // If changing id or type we need to check whether a matching resource already exists
        if type == _type && id == _id {
            return true
        }
        if _document.dataSource()?.resource(ofType: type, andID: Int16(id)) != nil {
//            let message = String(format: NSLocalizedString("A resource of type '%@' with ID %d already exists.", comment: ""), type, id)
//            let error = NSError(domain: NSCocoaErrorDomain, code: NSKeyValueValidationError, userInfo: [
//                NSLocalizedDescriptionKey: message
//            ])
            document?.presentError(ResourceError.conflict(type, id))
            return false
        }
        return true
    }

    /* encoding */
    
    required init?(coder: NSCoder) {
        _type = coder.decodeObject() as! String
        _id = coder.decodeObject() as! Int
        name = coder.decodeObject() as! String
        attributes = ResAttributes(rawValue: coder.decodeObject() as! Int)
        data = coder.decodeData()!
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(_type)
        coder.encode(_id)
        coder.encode(name)
        coder.encode(attributes.rawValue)
        coder.encode(data)
    }
}
