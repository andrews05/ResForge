import Cocoa

class Menu: NSObject {
    static let nameDidChangeNotification = Notification.Name("MENUNameDidChangeNotification")
    static let enabledDidChangeNotification = Notification.Name("MENUEnabledDidChangeNotification")

    var menuID: Int16 = 128
    var mdefID: Int16 = 0
    var enableFlags: UInt32 = UInt32.max
    var isEnabled: Bool {
        set(newValue) {
            setEnabled(newValue, at: -1)
            NotificationCenter.default.post(name: Menu.nameDidChangeNotification, object: self)
        }
        get {
            return isEnabled(at: -1)
        }
    }
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
    
    /// Change the enable state of the given item. -1 changes the menu itself, as does ``isEnabled``.
    /// - warning: This doesn't send notifications.
    func setEnabled(_ state: Bool, at index: Int) {
        guard index < 32 else { return }
        if state {
            enableFlags |= (1 << (index + 1))
        } else {
            enableFlags &= ~(1 << (index + 1))
        }
    }
    
    /// Is the given item enabled? -1 gives the menu itself, as does ``isEnabled``.
    func isEnabled(at index: Int) -> Bool {
        guard index < 32 else { return isEnabled(at: -1) }
        return (enableFlags & (1 << (index + 1))) != 0
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
    var menuCommand: UInt32 { return 0 }
    var styleByte: UInt8 { return 0 }
    var iconID: Int { return 0 }
    var iconImage: NSImage? { return nil }
    var submenuID: Int { return 0 }

    var isItem: Bool { return false }
    var has4CCCommand: Bool { return false }
    var hasInt16Command: Bool { return false }
    var iconType: UInt8 { return 0 }

    override func value(forKey key: String) -> Any? {
        if key == "markCharacter" {
            return markCharacter
        } else if key == "keyEquivalent" {
            return keyEquivalent
        } else if key == "name" {
            return name
        } else if key == "hasKeyEquivalent" {
            return hasKeyEquivalent
        } else if key == "isEnabled" {
            return isEnabled
        } else if key == "menuID" {
            return menuID
        } else if key == "mdefID" {
            return mdefID
        } else if key == "menuCommand" {
            return menuCommand
        } else if key == "styleByte" {
            return styleByte
        } else if key == "iconID" {
            return iconID
        } else if key == "iconImage" {
            return iconImage
        } else if key == "iconType" {
            return iconType
        } else if key == "submenuID" {
            return submenuID
        } else if key == "has4CCCommand" {
            return has4CCCommand
        } else if key == "hasInt16Command" {
            return hasInt16Command
        } else if key == "isItem" {
            return isItem
        } else if key == "textColor" {
            return isEnabled ? NSColor.textBackgroundColor : NSColor.systemGray
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
        } else if key == "isEnabled" {
            isEnabled = value as? Bool ?? true
        } else if key == "mdefID" {
            mdefID = Int16(value as? Int ?? 0)
        } else if key == "menuID" {
            menuID = Int16(value as? Int ?? 0)
        } else {
            super.setValue(value, forKey: key)
        }
    }
    
    override var description: String {
        return "\(self.className)(name = \"\(name)\", id = \(menuID)){" + items.map({ $0.description }).joined(separator: ", ") + "}"
    }
    
}
