import Cocoa

/*
 * NSRuleEditor provides a great interface for type attributes but has proven difficult to work with.
 * In particular, providing the initial data is not easy, especially as the "rows" binding appears to be buggy (and crashy).
 * Here we store row values in property each time a row is added, which are subsequently accessed by the delegate function.
 */
class AttributesEditor: NSRuleEditor, NSRuleEditorDelegate, NSTextFieldDelegate {
    @IBOutlet var addButton: NSButton?
    @IBOutlet var applyButton: NSButton?
    
    private var currentRowValues = [String: NSTextField]()
    var attributes: [String: String] {
        get {
            var atts = [String: String]()
            for i in 0..<self.numberOfRows {
                let values = self.displayValues(forRow: i)
                let key = (values[0] as! NSTextField).stringValue
                let value = (values[2] as! NSTextField).stringValue
                if !key.isEmpty && !value.isEmpty {
                    atts[key] = value
                }
            }
            return atts
        }
        set {
            self.clear(self)
            for (key, value) in newValue {
                self.insertRow(at: self.numberOfRows, key: key, value: value, makeFirstResponder: false)
            }
            applyButton?.isHidden = true
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.delegate = self
    }
    
    @IBAction func addOrClear(_ sender: Any) {
        if self.numberOfRows == 0 {
            self.addRow(sender)
        } else {
            self.clear(sender)
        }
    }
    
    @IBAction func clear(_ sender: Any) {
        self.removeRows(at: IndexSet(0..<self.numberOfRows), includeSubrows: true)
    }
    
    override func insertRow(at rowIndex: Int, with rowType: NSRuleEditor.RowType, asSubrowOfRow parentRow: Int, animate shouldAnimate: Bool) {
        self.insertRow(at: rowIndex)
    }
    
    private func insertRow(at rowIndex: Int, key: String = "", value: String = "", makeFirstResponder: Bool = true) {
        let keyField = self.keyField(key)
        currentRowValues = ["key": keyField, "val": self.valueField(value)]
        super.insertRow(at: rowIndex, with: .simple, asSubrowOfRow: -1, animate: false)
        if makeFirstResponder {
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(keyField)
            }
        }
    }
    
    private func keyField(_ key: String) -> NSTextField {
        let field = self.valueField(key, width: 200)
        field.formatter = AttributeNameFormatter.shared
        return field
    }
    
    private func valueField(_ value: String, width: CGFloat = 225) -> NSTextField {
        let field = NSTextField(frame: NSMakeRect(0, 0, width, 20))
        field.stringValue = value
        field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        field.usesSingleLineMode = true
        field.lineBreakMode = .byTruncatingTail
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
        return currentRowValues[criterion as! String] ?? criterion
    }
    
    func ruleEditorRowsDidChange(_ notification: Notification) {
        addButton?.image = NSImage(named: self.numberOfRows == 0 ? NSImage.addTemplateName : NSImage.removeTemplateName)
        applyButton?.isHidden = false
    }
    
    func controlTextDidChange(_ obj: Notification) {
        applyButton?.isHidden = false
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
