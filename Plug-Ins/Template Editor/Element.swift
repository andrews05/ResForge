import Cocoa

class Element: ValueTransformer, NSCopying, NSComboBoxDelegate {
    /// Type code of this field.
    private(set) var type: String
    /// Label ("name") of this field.
    private(set) var label: String
    /// Descriptive tooltip of this field, derived from subsequent lines of the label.
    private(set) var tooltip: String
    /// The list of the template field containing us, or the template window's list.
    weak var parentList: ElementList!
    /// Type code of an ending element if this element marks the start of a section.
    private(set) var endType: String! = nil
    private(set) var rowHeight: Double = 22
    private(set) var visible: Bool = true
    private(set) var width: CGFloat = 60 // Default for many types
    
    /// The label to display, if different from the template label.
    var displayLabel: String {
        label.components(separatedBy: "=").first ?? ""
    }
    /// Create a shared (static) formatter for displaying your data in the list.
    static var sharedFormatter: Formatter? {
        nil
    }
    /// Override this if the formatter should not be shared.
    var formatter: Formatter? {
        Self.sharedFormatter
    }
    
    init(for type: String, withLabel label: String) {
        self.type = type
        // Any extra lines in the label will be used as a tooltip
        let components = label.components(separatedBy: "\n")
        self.label = components[0]
        if components.count > 1 {
            tooltip = components[1...].joined(separator: "\n")
        } else {
            tooltip = ""
        }
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let element = Element(for: type, withLabel: label)
        element.tooltip = tooltip
        return element
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
    
    // Items that have sub-items (like LSTB, LSTZ, LSTC and other lists) should implement these:
    func hasSubElements() -> Bool {
        return false
    }
    func subElementCount() -> Int {
        return 0
    }
    func subElement(at index: Int) -> Element? {
        return nil
    }
    
    /// Perform any configuration that may depend on other elements.
    func configure() {}
    
    /// Read the value of the field from the stream.
    func readData(from stream: ResourceStream) {}
    
    /// Before writeData is called, this is called to calculate the final resource size.
    /// Items with sub-elements should return the sum of the sizes of all their sub-elements here as well.
    func sizeOnDisk() -> UInt32 {
        return 0
    }
    
    /// Write the value of the field to the stream.
    func writeData(to stream: ResourceStream) {}
}
