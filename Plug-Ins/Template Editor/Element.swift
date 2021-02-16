import Cocoa
import RFSupport

class Element: ValueTransformer, NSTextFieldDelegate {
    static var sharedFormatters: [String: Formatter] = [:]
    
    /// Type code of this field.
    let type: String
    /// Label ("name") of this field.
    let label: String
    /// Descriptive tooltip of this field, derived from subsequent lines of the label.
    var tooltip: String
    /// The label to display, if different from the template label.
    var displayLabel: String
    /// Type code of an ending element if this element marks the start of a section.
    var endType: String!
    /// The list of the template field containing us, or the template window's list.
    weak var parentList: ElementList!
    var rowHeight: Double = 22
    var visible: Bool = true
    var width: CGFloat = 60 // Default for many types

    
    required init!(type: String, label: String, tooltip: String? = nil) {
        self.type = type
        if let tooltip = tooltip {
            self.label = label
            self.tooltip = tooltip
        } else {
           let lines = label.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
           if lines.count == 2 {
                self.label = String(lines[0])
                self.tooltip = String(lines[1])
            } else {
                self.label = label
                self.tooltip = ""
            }
        }
        displayLabel = self.label.components(separatedBy: "=")[0]
    }
    
    func copy() -> Self {
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
        if commandSelector == #selector(NSTextView.insertBacktab(_:)) && (control.previousValidKeyView == nil || control.previousValidKeyView == outline) {
            outline?.selectPreviousKeyView(control)
            return true
        }
        if commandSelector == #selector(NSTextView.insertTab(_:)) && control.nextValidKeyView == nil {
            outline?.selectNextKeyView(control)
            return true
        }
        return false
    }
    
    // This is required here for subclasses to override
    func controlTextDidChange(_ obj: Notification) {}
    
    // Check if this element is at the end of either the template, a sized/skip section, or a keyed section which is itself at the end.
    // I.E. Check that there is no more data to be read after this.
    func isAtEnd() -> Bool {
        let topLevel: Bool
        if let parent = self.parentList.parentElement {
            topLevel = parent.endType == "SKPE" || (parent.endType == "KEYE" && parent.isAtEnd())
        } else {
            topLevel = true
        }
        return topLevel && self.parentList.peek(1) == nil
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
        frame.size.height = CGFloat(rowHeight)
        if width != 0 {
            frame.size.width = width - 4
        }
        let textField = NSTextField(frame: frame)
        textField.formatter = formatter
        textField.delegate = self
        textField.placeholderString = type
        textField.lineBreakMode = .byTruncatingTail
        textField.allowsDefaultTighteningForTruncation = true
        textField.bind(.value, to: self, withKeyPath: "value", options: nil)
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
    
    /// Write the value of the field to the stream.
    func writeData(to writer: BinaryDataWriter) {}
    
    /// Obtain a formatter for this element's data.
    var formatter: Formatter? {
        if Self.sharedFormatters[type] == nil {
            Self.sharedFormatters[type] = Self.formatter
        }
        return Self.sharedFormatters[type]
    }
    
    /// Create a shared formatter for this element's data.
    class var formatter: Formatter? {
        nil
    }
}

protocol GroupElement where Self: Element {
    func configureGroup(view: NSTableCellView)
}
