import AppKit
import RFSupport

class MenuItem: NSObject {
    
    enum CommandsSize {
        case none
        case int16
        case int32
    }
    
    static let nameDidChangeNotification = Notification.Name("MENUItemNameDidChangeNotification")
    static let keyEquivalentDidChangeNotification = Notification.Name("MENUItemKeyEquivalentDidChangeNotification")
    static let markCharacterDidChangeNotification = Notification.Name("MENUItemMarkCharacterDidChangeNotification")
    static let styleByteDidChangeNotification = Notification.Name("MENUItemStyleByteDidChangeNotification")
    static let menuCommandDidChangeNotification = Notification.Name("MENUItemCommandByteDidChangeNotification")
    static let enabledDidChangeNotification = Notification.Name("MENUItemEnabledDidChangeNotification")
    static let iconDidChangeNotification = Notification.Name("MENUItemIconDidChangeNotification")
    static let submenuIDDidChangeNotification = Notification.Name("MENUItemSubmenuIDDidChangeNotification")

    var name = "" {
        didSet {
            NotificationCenter.default.post(name: MenuItem.nameDidChangeNotification, object: self)
        }
    }
    var iconID = Int(0) {
        didSet {
            if iconID != 0,
               let res = manager.findResource(type: .icon, id: iconID) {
                res.preview({ img in
                    self.willChangeValue(forKey: "iconImage")
                    self.iconImage = img
                    self.didChangeValue(forKey: "iconImage")
                })
                NotificationCenter.default.post(name: MenuItem.iconDidChangeNotification, object: self) // This is *only* the change of the icon ID. Image loading isn't a change (otherwise every resource would open and immediately be edited)
            } else {
                self.willChangeValue(forKey: "iconImage")
                self.iconImage = nil
                self.didChangeValue(forKey: "iconImage")
                NotificationCenter.default.post(name: MenuItem.iconDidChangeNotification, object: self)
            }
        }
    }
    var submenuID = Int(0) {
        didSet {
            NotificationCenter.default.post(name: MenuItem.submenuIDDidChangeNotification, object: self)
        }
    }
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
    let commandsSize: CommandsSize
    
    var isEnabled: Bool = true {
        didSet {
            NotificationCenter.default.post(name: MenuItem.enabledDidChangeNotification, object: self)
        }
    }
    
    var iconImage: NSImage?
    var iconType: UInt8

    var hasKeyEquivalent: Bool {
        return !keyEquivalent.isEmpty
    }
    
    var has4CCCommand: Bool {
        return commandsSize == .int32
    }

    var hasInt16Command: Bool {
        return commandsSize == .int16
    }

    let manager: RFEditorManager
    
    internal init(name: String = "", iconID: Int = Int(0), iconType: UInt8 = 0, keyEquivalent: String = "", markCharacter: String = "", styleByte: UInt8 = UInt8(0), menuCommand: UInt32 = UInt32(0), isEnabled: Bool = true, submenuID: Int = 0, commandsSize: CommandsSize, manager: RFEditorManager) {
        self.name = name
        self.iconID = iconID
        self.iconType = iconType
        self.keyEquivalent = keyEquivalent
        self.markCharacter = markCharacter
        self.styleByte = styleByte
        self.menuCommand = menuCommand
        self.isEnabled = isEnabled
        self.submenuID = submenuID
        self.commandsSize = commandsSize
        self.manager = manager
        
        super.init()
        
        if iconID != 0,
           let res = manager.findResource(type: .icon, id: iconID) {
            res.preview({ img in
                self.willChangeValue(forKey: "iconImage")
                self.iconImage = img
                self.didChangeValue(forKey: "iconImage")
            })
        }

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
            if commandsSize == .int32 {
                return menuCommand.fourCharString
            } else {
                return "\(menuCommand)"
            }
        } else if key == "styleByte" {
            return styleByte
        } else if key == "iconType" {
            return iconType
        } else if key == "isEnabled" {
            return isEnabled
        } else if key == "iconID" {
            return "\(iconID)"
        } else if key == "submenuID" {
            return "\(submenuID)"
        } else if key == "iconImage" {
            return iconImage
        } else if key == "isItem" {
            return isItem
        } else if key == "has4CCCommand" {
            return has4CCCommand
        } else if key == "hasInt16Command" {
            return hasInt16Command
        } else if key == "textColor" {
            return isEnabled ? NSColor.textColor : NSColor.disabledControlTextColor
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
        } else if key == "iconID" {
            iconID = value as? Int ?? 0
        } else if key == "submenuID" {
            submenuID = value as? Int ?? 0
        } else if key == "menuCommand" {
            if commandsSize == .int32 {
                menuCommand = UInt32(fourCharString: value as? String ?? "")
            } else {
                menuCommand = value as? UInt32 ?? 0
            }
        } else if key == "styleByte" {
            styleByte = value as? UInt8 ?? 0
        } else if key == "iconType" {
            iconType = value as? UInt8 ?? 0
        } else {
            super.setValue(value, forKey: key)
        }
    }
    
}

// So menu and menu item can be treated identically by UI.
extension MenuItem {
    var menuID: Int16 { return 0 }
    var mdefID: Int16 { return 0 }
    
    var isItem: Bool { return true }
}

extension MenuItem {
    override var description: String {
        return "\(self.className)(name = \"\(name)\", keyEquivalent = \"\(keyEquivalent)\", markCharacter = \"\(markCharacter)\")"
    }
}
