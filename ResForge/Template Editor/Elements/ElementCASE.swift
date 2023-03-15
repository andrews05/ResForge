import Cocoa
import RFSupport

class ElementCASE: Element {
    @objc var value: AnyHashable!
    var displayValue: String { metaValue ?? displayLabel }

    convenience init(value: AnyHashable, displayLabel: String, displayValue: String) {
        self.init(type: "CASE", label: "")
        self.value = value
        self.displayLabel = displayLabel
        self.metaValue = displayValue
    }

    // For key elements, the case's description is used in the popup menu
    override var description: String {
        displayLabel
    }

    // Configure will only be called if the CASE is not associated to a supported element.
    // If this happens we will just show the label as a help tip below the previous element.
    override func configure() throws {
        displayLabel = ""
        rowHeight = 16
    }

    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y -= 2
        let textField = NSTextField(frame: frame)
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.stringValue = label
        textField.textColor = .secondaryLabelColor
        textField.drawsBackground = false
        view.addSubview(textField)
    }

    func configure(for element: FormattedElement) throws {
        do {
            value = try element.formatter.getObjectValue(for: displayValue) as? AnyHashable
        } catch let error {
            throw TemplateError.invalidStructure(self, error.localizedDescription)
        }
    }
}
