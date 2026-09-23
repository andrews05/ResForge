import AppKit
import RFSupport

class MenuItem: NSObject {
    struct Styles: OptionSet, Hashable {
        public let rawValue: UInt8
        public static let bold      = Self(rawValue: 1)
        public static let italic    = Self(rawValue: 2)
        public static let underline = Self(rawValue: 4)
        public static let outline   = Self(rawValue: 8)
        public static let shadow    = Self(rawValue: 16)
        public static let condensed = Self(rawValue: 32)
        public static let extended  = Self(rawValue: 64)
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    static let hasSubmenu: UInt8 = 0x1B
    static let hasScriptCode: UInt8 = 0x1C
    static let reduceIcon: UInt8 = 0x1D
    static let useSICN: UInt8 = 0x1E

    unowned let editor: MenuEditor

    @objc var isEnabled = true {
        didSet {
            textColor = isEnabled ? .controlTextColor : .disabledControlTextColor
            editor.setDocumentEdited(true)
        }
    }
    @objc var name = "New Menu Item" {
        didSet {
            editor.updateRow(for: self)
            editor.setDocumentEdited(true)
        }
    }
    @objc dynamic var iconCode: UInt8 = 0 {
        didSet {
            updateIcon()
            editor.setDocumentEdited(true)
        }
    }
    @objc dynamic var keyCode: UInt8 = 0 {
        didSet {
            hasKeyEquivalent = !(Self.hasSubmenu...Self.useSICN ~= keyCode)
            hasValidKeyEquivalent = keyCode > 0x20
            hasIcon = keyCode != Self.hasScriptCode
            hasSubmenu = keyCode == Self.hasSubmenu
            hasScriptCode = keyCode == Self.hasScriptCode
            if hasIcon != (oldValue != Self.hasScriptCode) {
                updateIcon()
            }
            editor.setDocumentEdited(true)
        }
    }
    @objc var markCode: UInt8 = 0 {
        didSet {
            editor.setDocumentEdited(true)
        }
    }
    var style = Styles() {
        didSet {
            editor.setDocumentEdited(true)
        }
    }
    @objc var menuCommand: UInt32 = 0 {
        didSet {
            editor.setDocumentEdited(true)
        }
    }

    @objc dynamic var textColor = NSColor.textColor
    @objc dynamic var iconImage: NSImage?
    @objc dynamic var hasKeyEquivalent = true
    @objc dynamic var hasValidKeyEquivalent = false
    @objc dynamic var hasIcon = true
    @objc dynamic var hasSubmenu = false
    @objc dynamic var hasScriptCode = false

    init(editor: MenuEditor) {
        self.editor = editor
        super.init()
    }

    private func updateIcon() {
        if hasIcon,
           let iconID = iconID as? Int,
           let icon = editor.manager.findResource(type: .colorIcon, id: iconID) ?? editor.manager.findResource(type: .icon, id: iconID) {
            icon.preview { [weak self] img in
                // Check hasIcon again in case it changed
                if let self, hasIcon {
                    iconImage = img
                }
            }
        } else {
            iconImage = nil
        }
    }
}

extension MenuItem {
    @objc var has4CCCommand: Bool {
        editor.commandSize == .int32
    }
    @objc var hasInt16Command: Bool {
        editor.commandSize == .int16
    }
    
    @objc var special: UInt8 {
        get {
            hasKeyEquivalent ? 0 : keyCode
        }
        set {
            keyCode = newValue
            editor.updateRow(for: self)
        }
    }

    // The icon ID is the byte value + 256, if not zero
    // So the UI has a number formatter in the range 257-511 and we use blank/nil to reset to zero
    // We have to use `NSNumber?` for this as `Int?` is not @objc-compatible
    @objc var iconID: NSNumber? {
        get {
            iconCode == 0 ? nil : (Int(iconCode) + 256) as NSNumber
        }
        set {
            iconCode = newValue.map({ UInt8($0.intValue - 256) }) ?? 0
        }
    }

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        switch key {
        case "iconID": ["iconCode"]
        default: []
        }
    }

    // Style bindings
    @objc var isBold: Bool {
        get { style.contains(.bold) }
        set { style.formSymmetricDifference(.bold) }
    }
    @objc var isItalic: Bool {
        get { style.contains(.italic) }
        set { style.formSymmetricDifference(.italic) }
    }
    @objc var isUnderline: Bool {
        get { style.contains(.underline) }
        set { style.formSymmetricDifference(.underline) }
    }
    @objc var isOutline: Bool {
        get { style.contains(.outline) }
        set { style.formSymmetricDifference(.outline) }
    }
    @objc var isShadow: Bool {
        get { style.contains(.shadow) }
        set { style.formSymmetricDifference(.shadow) }
    }
    @objc var isCondensed: Bool {
        get { style.contains(.condensed) }
        set { style.formSymmetricDifference(.condensed) }
    }
    @objc var isExtended: Bool {
        get { style.contains(.extended) }
        set { style.formSymmetricDifference(.extended) }
    }
}
