import Cocoa

class AttributesEditor: NSRuleEditor, NSRuleEditorDelegate, NSTextFieldDelegate {
    @IBOutlet var addButton: NSButton?
    @IBOutlet var applyButton: NSButton?
    
    @objc dynamic var rows: [TypeAttribute] = []
    var attributes: [String: String] {
        get {
            return rows.reduce(into: [:]) {
                if !$1.key.isEmpty && !$1.value.isEmpty {
                    $0[$1.key] = $1.value
                }
            }
        }
        set {
            rows = newValue.map { TypeAttribute(self.keyField($0), self.valueField($1)) }
            applyButton?.isHidden = true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = self
        self.rowClass = TypeAttribute.self
        self.bind(NSBindingName(rawValue: "rows"), to: self, withKeyPath: "rows", options: nil)
    }
    
    @IBAction func addOrClear(_ sender: Any) {
        if rows.isEmpty {
            self.addRow(sender)
        } else {
            rows.removeAll()
        }
    }
    
    func keyField(_ key: String = "") -> NSTextField {
        let field = self.valueField(key, width: 100)
        field.formatter = AttributeNameFormatter.shared
        return field
    }
    
    func valueField(_ value: String = "", width: CGFloat = 120) -> NSTextField {
        let field = NSTextField(frame: NSMakeRect(0, 0, width, 20))
        field.stringValue = value
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.delegate = self
        return field
    }
    
    // MARK: Delegate Functions
    func ruleEditor(_ editor: NSRuleEditor, numberOfChildrenForCriterion criterion: Any?, with rowType: NSRuleEditor.RowType) -> Int {
        return (criterion as? String) == "val" ? 0 : 1
    }
    
    func ruleEditor(_ editor: NSRuleEditor, child index: Int, forCriterion criterion: Any?, with rowType: NSRuleEditor.RowType) -> Any {
        switch criterion as? String {
        case "key":
            return "="
        case "=":
            return "val"
        default:
            return "key"
        }
    }
    
    func ruleEditor(_ editor: NSRuleEditor, displayValueForCriterion criterion: Any, inRow row: Int) -> Any {
        switch criterion as? String {
        case "key":
            return self.keyField()
        case "=":
            return "="
        default:
            return self.valueField()
        }
    }
    
    func ruleEditorRowsDidChange(_ notification: Notification) {
        addButton?.image = NSImage(named: rows.isEmpty ? NSImage.addTemplateName : NSImage.removeTemplateName)
        applyButton?.isHidden = false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        applyButton?.isHidden = false
    }
}

class TypeAttribute: NSObject {
    @objc var rowType = NSRuleEditor.RowType.simple
    @objc var subrows: [Any] = []
    @objc var criteria = ["key", "=", "val"]
    @objc var displayValues: [Any] = []
    var key: String {
        (displayValues[0] as! NSTextField).stringValue
    }
    var value: String {
        (displayValues[2] as! NSTextField).stringValue
    }
    
    override init() {
        super.init()
        DispatchQueue.main.async {
            if let field = self.displayValues[0] as? NSTextField {
                field.window?.makeFirstResponder(field)
            }
        }
    }
    
    init(_ key: NSTextField, _ value: NSTextField) {
        displayValues = [key, "=", value]
    }
}

class AttributeNameFormatter: Formatter {
    static var shared = AttributeNameFormatter()
    
    let disallowed = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_").inverted
    
    override func string(for obj: Any?) -> String? {
        return obj as? String
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if string.isEmpty {
            error?.pointee = NSLocalizedString("The value must be not be blank.", comment: "") as NSString
            return false
        }
        if string.rangeOfCharacter(from: disallowed) != nil {
            error?.pointee = NSLocalizedString("The value contains invalid characters.", comment: "") as NSString
            return false
        }
        obj?.pointee = string as AnyObject
        return true
    }
    
    override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>,
                                       proposedSelectedRange proposedSelRangePtr: NSRangePointer?,
                                       originalString origString: String,
                                       originalSelectedRange origSelRange: NSRange,
                                       errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if partialStringPtr.pointee.rangeOfCharacter(from: disallowed).location != NSNotFound {
            // Perform the removal
            let len = partialStringPtr.pointee.length
            partialStringPtr.pointee = partialStringPtr.pointee.components(separatedBy: disallowed).joined() as NSString
            
            // Fix-up the proposed selection range
            proposedSelRangePtr?.pointee.location -= len - partialStringPtr.pointee.length
            proposedSelRangePtr?.pointee.length = 0
            NSSound.beep()
            return false
        }
        
        return true
    }
}
