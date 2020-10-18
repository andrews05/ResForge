import Cocoa
import RKSupport

class Element: ValueTransformer, NSCopying, NSTextFieldDelegate {
    static var sharedFormatters: [String: Formatter] = [:]
    
    /// Type code of this field.
    let type: String
    /// Label ("name") of this field.
    let label: String
    /// Descriptive tooltip of this field, derived from subsequent lines of the label.
    var tooltip: String
    /// Type code of an ending element if this element marks the start of a section.
    var endType: String! = nil
    /// The list of the template field containing us, or the template window's list.
    weak var parentList: ElementList!
    var rowHeight: Double = 22
    var visible: Bool = true
    var width: CGFloat = 60 // Default for many types
    
    /// The label to display, if different from the template label.
    var displayLabel: String {
        label.components(separatedBy: "=")[0]
    }
    /// Create a formatter for this element's data..
    var formatter: Formatter? {
        nil
    }
    
    required init(type: String, label: String, tooltip: String = "") {
        self.type = type
        self.label = label
        self.tooltip = tooltip
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        return Self.init(type: type, label: label, tooltip: tooltip)
    }
    
    // Notify the controller when a field has been edited
    // Use control:textShouldEndEditing: rather than controlTextDidEndEditing: as it more accurately reflects when the value has actually changed
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        (control.window?.windowController as? TemplateWindowController)?.itemValueUpdated(control)
        return true
    }
    
    // Allow tabbing between rows
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let outline = parentList.controller.dataList
        switch commandSelector {
        case #selector(NSTextView.insertBacktab(_:)):
            outline?.selectPreviousKeyView(control)
            return true
        case #selector(NSTextView.insertTab(_:)):
            outline?.selectNextKeyView(control)
            return true
        default:
            return false
        }
    }
    
    // MARK: - Methods Subclasses Should Override
    
    /// Perform any configuration that may depend on other elements.
    func configure() throws {}
    
    /// Configure the view to display this element in the list.
    /// The default implementation creates a text field bound to a "value" property.
    func configure(view: NSView) {
        // Element itself has no value - only do this for subclasses
        guard Swift.type(of: self) != Element.self else {
            return
        }
        var frame = view.frame
        if width != 0 {
            frame.size.width = width - 4
        }
        let textField = NSTextField(frame: frame)
        textField.formatter = formatter
        textField.delegate = self
        textField.placeholderString = type
        textField.lineBreakMode = .byTruncatingTail
        textField.allowsDefaultTighteningForTruncation = true
        textField.bind(NSBindingName("value"), to: self, withKeyPath: "value", options: nil)
        view.addSubview(textField)
    }
    
    // Items that have sub-items (like lists or keyed-sections) should implement these:
    var hasSubElements: Bool {
        false
    }
    var subElementCount: Int {
        0
    }
    func subElement(at index: Int) -> Element {
        return self // This is invalid but the function shouldn't be called here
    }
    
    /// Read the value of the field from the stream.
    func readData(from reader: BinaryDataReader) throws {}
    
    /// Before writeData is called, this is called to calculate the final resource size.
    /// Items with sub-elements should return the sum of the sizes of all their sub-elements here as well.
    func dataSize(_ size: inout Int) {}
    
    /// Write the value of the field to the stream.
    func writeData(to writer: BinaryDataWriter) {}
}

protocol GroupElement where Self: Element {
    func configureGroup(view: NSTableCellView)
}
