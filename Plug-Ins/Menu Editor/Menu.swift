import Foundation

class Menu: NSObject {
    static let nameDidChangeNotification = Notification.Name("MENUNameDidChangeNotification")
    
    var menuID: Int16 = 128
    var mdefID: Int16 = 0
    var enableFlags: UInt32 = UInt32.max
    var name = "New Menu" {
        didSet {
            NotificationCenter.default.post(name: Menu.nameDidChangeNotification, object: self)
        }
    }
    var items = [MenuItem]()
    
    internal init(menuID: Int16 = 128, mdefID: Int16 = 0, enableFlags: UInt32 = UInt32.max, name: String = "New Menu", items: [MenuItem] = [MenuItem]()) {
        self.menuID = menuID
        self.mdefID = mdefID
        self.enableFlags = enableFlags
        self.name = name
        self.items = items
    }
    
}

// So Key-value-coding from an NSTableView can treat the menu (title) object same as any item.
extension Menu {
    var keyEquivalent: String {
        get {
            return ""
        }
        set {
            
        }
    }
    var markCharacter: String {
        get {
            return ""
        }
        set {
            
        }
    }
    
    var hasKeyEquivalent: Bool {
        return false
    }

    override func value(forKey key: String) -> Any? {
        if key == "markCharacter" {
            return markCharacter
        } else if key == "keyEquivalent" {
            return keyEquivalent
        } else if key == "name" {
            return name
        } else if key == "hasKeyEquivalent" {
            return hasKeyEquivalent
        } else {
            return super.value(forKey: key)
        }
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        if key == "markCharacter" {
            markCharacter = value as? String ?? ""
        } else if key == "keyEquivalent" {
            keyEquivalent = value as? String ?? ""
        } else if key == "name" {
            name = value as? String ?? ""
        } else {
            super.setValue(value, forKey: key)
        }
    }
    
    override var description: String {
        return "\(self.className)(name = \"\(name)\"){" + items.map({ $0.description }).joined(separator: ", ") + "}"
    }
    
}
