import Cocoa
import RFSupport

class Element: ValueTransformer, NSTextFieldDelegate, TemplateField {
    static var sharedFormatters: [String: Formatter] = [:]
    
    /// Type code of this field.
    let type: String
    /// Label ("name") of this field.
    let label: String
    /// Descriptive tooltip of this field (derived from subsequent lines of the label).
    var tooltip: String
    /// The label to display, if different from the template label.
    var displayLabel: String
    /// Meta information for the element (the part of the label following the first "=").
    var metaValue: String?
    /// The list of the template field containing us, or the template window's list.
    weak var parentList: ElementList!
    var rowHeight: Double = 22
    var visible: Bool = true
    var width: CGFloat = 60 // Default for many types

    
    required init!(type: String, label: String) {
        self.type = type
        self.label = label
        let lines = label.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        tooltip = lines.count == 2 ? String(lines[1]) : ""
        let parts = lines[0].split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        displayLabel = String(parts[0])
        if parts.count == 2 {
            metaValue = String(parts[1])
        }
    }
    
    func copy() -> Self {
        return Self.init(type: type, label: label)
    }
    
    // Notify the controller when a field has been edited
    // Use control:textShouldEndEditing: rather than controlTextDidEndEditing: as it more accurately reflects when the value has actually changed
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        self.parentList?.controller.itemValueUpdated(control)
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
    
    // Check if this element is at the end of either the template, a sized/skip section, or a keyed section which is itself at the end.
    // I.E. Check that there is no more data to be read after this.
    func isAtEnd() -> Bool {
        let topLevel: Bool
        if let parent = self.parentList.parentElement as? CollectionElement {
            topLevel = parent.endType == "SKPE" || (parent.endType == "KEYE" && parent.isAtEnd())
        } else {
            topLevel = self.parentList.parentElement == nil
        }
        return topLevel && self.parentList.peek(1) == nil
    }
    
    // Get the value of the hex suffix of a variable Xnnn type
    static func variableTypeValue(_ type: String) -> Int {
        return Int(type.suffix(3), radix: 16)!
    }
    
    // MARK: - Functions subclasses should override
    
    /// Perform any configuration that may depend on other elements.
    func configure() throws {
        // Throw if not a subclass (typically ending elements such as LSTE).
        if Self.self == Element.self {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Not expected at this position.", comment: ""))
        }
    }
    
    /// Configure the view to display this element in the list.
    func configure(view: NSView) {}
    
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

/// An element that may have associated CASE elements.
class CasedElement: Element {
    // This is marked as @objc so that KeyElement can bind to it
    @objc var cases: [ElementCASE] = []
    var caseMap: [AnyHashable: ElementCASE] = [:]
    
    func readCases() throws {
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            try caseEl.configure(for: self)
            guard caseMap[caseEl.value] == nil else {
                throw TemplateError.invalidStructure(caseEl, NSLocalizedString("Duplicate value.", comment: ""))
            }
            cases.append(caseEl)
            caseMap[caseEl.value] = caseEl
        }
    }
}

/// An element that may contain child elements.
protocol CollectionElement where Self: Element {
    var endType: String { get }
    var subElementCount: Int { get }
    func subElement(at index: Int) -> Element
}

/// An element that is displayed as a group row in the outline view.
protocol GroupElement where Self: Element {
    func configureGroup(view: NSTableCellView)
}
