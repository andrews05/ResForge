import Cocoa
import RFSupport

// Allows editing the resource name within the template
class ElementRNAM: CasedElement {
    @objc var value = ""

    override func configure() throws {
        // RNAM can only appear once and must be the first element
        guard parentList.parentElement == nil && parentList.element(at: 0) == self else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Must be first element in template.", comment: ""))
        }
        width = 240
        try super.configure()
        // In case data isn't read (resource is empty) we still need to ensure the value is populated
        value = parentList.controller.resource.name
    }

    override func configure(view: NSView) {
        super.configure(view: view)
        let textField = view.subviews.last as! NSTextField
        textField.placeholderString = NSLocalizedString("Untitled Resource", comment: "")
    }

    override func readData(from reader: BinaryDataReader) {
        value = parentList.controller.resource.name
    }

    override func writeData(to writer: BinaryDataWriter) {
        parentList.controller.resource.name = value
    }

    override var formatter: Formatter {
        self.sharedFormatter {
            MacRomanFormatter(stringLength: 255)
        }
    }
}
