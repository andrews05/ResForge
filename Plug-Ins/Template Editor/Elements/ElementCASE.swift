import Cocoa
import RFSupport

class ElementCASE: Element {
    @objc var value: AnyHashable!
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        if meta.isEmpty {
            meta = displayLabel
        }
    }
    
    init(value: AnyHashable, displayValue: String) {
        super.init(type: "CASE", label: "")
        self.meta = displayValue
        self.value = value
    }
    
    // For key elements, the case's description is used in the popup menu
    override var description: String {
        self.displayLabel
    }
    
    // Configure will only be called if the CASE is not associated to a supported element.
    // If this happens we will just show the label as a help tip below the previous element.
    override func configure() throws {
        self.displayLabel = ""
        self.rowHeight = 16
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y -= 2
        let textField = NSTextField(frame: frame)
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.stringValue = self.label
        textField.textColor = .secondaryLabelColor
        textField.drawsBackground = false
        view.addSubview(textField)
    }
    
    func configure(for element: Element) throws {
        if let formatter = element.formatter {
            var errorString: NSString? = nil
            var ioValue: AnyObject?
            formatter.getObjectValue(&ioValue, for: meta, errorDescription: &errorString)
            if let errorString = errorString {
                throw TemplateError.invalidStructure(self, errorString as String)
            }
            value = ioValue as? AnyHashable
        } else {
            value = meta
        }
    }
}
