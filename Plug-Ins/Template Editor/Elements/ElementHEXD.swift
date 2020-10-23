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
            self.setRowHeight()
        }
        self.width = 240
    }
    
    override func configure(view: NSView) {
        let textField = NSTextField(frame: NSMakeRect(0, 3, self.width-4, CGFloat(self.rowHeight)-5))
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.font = NSFont.userFixedPitchFont(ofSize: 11)
        if let data = data {
            var count = 0
            textField.stringValue = data.map {
                count += 1
                return String(format: count.isMultiple(of: 4) ? "%02X " : "%02X", $0)
            } .joined()
        }
        view.addSubview(textField)
    }
    
    private func setRowHeight() {
        // 16 bytes per line, 17pt line height
        self.rowHeight = (ceil(Double(length) / 16) * 17) + 5
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        if self.type == "HEXD" {
            length = reader.data.endIndex - reader.position
            self.setRowHeight()
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
