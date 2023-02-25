import Cocoa
import RFSupport

// Allows editing the resource name within the template
class ElementRNAM: ElementCSTR {
    override func configure() throws {
        // RNAM can only appear once and must be the first element
        guard parentList.parentElement == nil && parentList.element(at: 0) == self else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Must be first element in template.", comment: ""))
        }
        try super.configure()
    }
    
    override func configurePadding() {
        maxLength = Int(UInt8.max)
    }
    
    override func configure(view: NSView) {
        super.configure(view: view)
        let textField = view.subviews.last as! NSTextField
        textField.placeholderString = "Untitled Resource"
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = parentList.controller.resource.name
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        parentList.controller.resource.name = value
    }
}
