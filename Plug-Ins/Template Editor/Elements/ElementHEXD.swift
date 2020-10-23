import Cocoa
import RKSupport

// Implements HEXD, Hnnn
class ElementHEXD: Element {
    var data: Data?
    var length = 0
    
    override func configure() throws {
        if self.type == "HEXD" {
            guard self.parentList.peek(1) == nil else {
                throw TemplateError.invalidStructure(self, NSLocalizedString("Must be last element in template.", comment: ""))
            }
        } else {
            // Hnnn
            length = Int(self.type.suffix(3), radix: 16)!
        }
    }
    
    override func configure(view: NSView) {
        let textField = NSTextField(frame: NSMakeRect(0, 3, view.frame.size.width, 17))
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.autoresizingMask = .width
        textField.stringValue = "\(length) bytes"
        view.addSubview(textField)
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        if self.type == "HEXD" {
            length = reader.data.endIndex - reader.position
        }
        data = try reader.readData(length: length)
    }
    
    override func dataSize(_ size: inout Int) {
        size += length
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if let data = self.data {
            writer.data.append(data)
        } else {
            writer.advance(length)
        }
    }
}
