import AppKit

class Menu: NSObject {
    unowned let editor: MenuEditor

    var enableFlags: UInt32 = UInt32.max
    @objc var isEnabled: Bool {
        get {
            isEnabled(at: -1)
        }
        set {
            setEnabled(newValue, at: -1)
            textColor = isEnabled ? .controlTextColor : .disabledControlTextColor
            editor.setDocumentEdited(true)
        }
    }
    @objc var name = "New Menu" {
        didSet {
            editor.setDocumentEdited(true)
        }
    }
    @objc var menuID: Int16 = 128 {
        didSet {
            editor.setDocumentEdited(true)
        }
    }
    @objc var mdefID: Int16 = 0 {
        didSet {
            editor.setDocumentEdited(true)
        }
    }

    var items: [MenuItem] = []
    @objc dynamic var textColor = NSColor.controlTextColor
    @objc var iconImage: NSImage? { nil } // Required for binding

    init(editor: MenuEditor) {
        self.editor = editor
    }

    /// Update the enable flags for the given item. -1 is for the menu itself.
    func setEnabled(_ state: Bool, at index: Int) {
        if state {
            enableFlags |= (1 << (index + 1))
        } else {
            enableFlags &= ~(1 << (index + 1))
        }
    }
    
    /// Is the given item enabled? -1 is for the menu itself.
    func isEnabled(at index: Int) -> Bool {
        return (enableFlags & (1 << (index + 1))) != 0
    }
}
