import Cocoa

class MenuItem: NSObject {
    
    static let nameDidChangeNotification = Notification.Name("MENUItemNameDidChangeNotification")
    static let keyEquivalentDidChangeNotification = Notification.Name("MENUItemKeyEquivalentDidChangeNotification")
    static let markCharacterDidChangeNotification = Notification.Name("MENUItemMarkCharacterDidChangeNotification")
    static let styleByteDidChangeNotification = Notification.Name("MENUItemStyleByteDidChangeNotification")
    static let menuCommandDidChangeNotification = Notification.Name("MENUItemCommandByteDidChangeNotification")
    static let enabledDidChangeNotification = Notification.Name("MENUItemEnabledDidChangeNotification")

    var name = "" {
        didSet {
            NotificationCenter.default.post(name: MenuItem.nameDidChangeNotification, object: self)
        }
    }
    var iconID = Int(0)
    var keyEquivalent = "" {
        didSet {
            NotificationCenter.default.post(name: MenuItem.keyEquivalentDidChangeNotification, object: self)
        }
    }
    var markCharacter = "" {
        didSet {
            NotificationCenter.default.post(name: MenuItem.markCharacterDidChangeNotification, object: self)
        }
    }
    var styleByte = UInt8(0) {
        didSet {
            NotificationCenter.default.post(name: MenuItem.styleByteDidChangeNotification, object: self)
        }
    }
    var menuCommand = UInt32(0) {
        didSet {
            NotificationCenter.default.post(name: MenuItem.menuCommandDidChangeNotification, object: self)
        }
    }
    
    var isEnabled: Bool = true {
        didSet {
            NotificationCenter.default.post(name: MenuItem.enabledDidChangeNotification, object: self)
        }
    }
    var hasKeyEquivalent: Bool {
        return !keyEquivalent.isEmpty
    }
    
    var isItem: Bool { return true }
    
    internal init(name: String = "", iconID: Int = Int(0), keyEquivalent: String = "", markCharacter: String = "", styleByte: UInt8 = UInt8(0), menuCommand: UInt32 = UInt32(0), isEnabled: Bool = true) {
        self.name = name
        self.iconID = iconID
        self.keyEquivalent = keyEquivalent
        self.markCharacter = markCharacter
        self.styleByte = styleByte
        self.menuCommand = menuCommand
        self.isEnabled = isEnabled
    }
    
}

extension MenuItem {
    
    override func value(forKey key: String) -> Any? {
        if key == "markCharacter" {
            return markCharacter
        } else if key == "keyEquivalent" {
            return keyEquivalent
        } else if key == "name" {
            return name
        } else if key == "menuID" {
            return menuID
        } else if key == "mdefID" {
            return mdefID
        } else if key == "menuCommand" {
            return menuCommand
        } else if key == "styleByte" {
            return styleByte
        } else if key == "isEnabled" {
            return isEnabled
        } else if key == "isItem" {
            return isItem
        } else if key == "textColor" {
            return isEnabled ? NSColor.black : NSColor.lightGray
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
        } else if key == "isEnabled" {
            isEnabled = value as? Bool ?? true
        } else if key == "menuCommand" {
            menuCommand = UInt32(Int(value as? String ?? "0") ?? 0)
        } else if key == "styleByte" {
            styleByte = value as? UInt8 ?? 0
        } else {
            super.setValue(value, forKey: key)
        }
    }
    
}

// So menu and menu item can be treated identically by UI.
extension MenuItem {
    var menuID: Int16 { return 0 }
    var mdefID: Int16 { return 0 }
}

extension MenuItem {
    override var description: String {
        return "\(self.className)(name = \"\(name)\", keyEquivalent = \"\(keyEquivalent)\", markCharacter = \"\(markCharacter)\")"
    }
}
