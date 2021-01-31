import Cocoa
import RKSupport

// Implements HEXD, Hnnn
class ElementHEXD: Element {
    var data: Data?
    var length = 0
    
    override func configure() throws {
        if self.type == "HEXD" || self.type == "CODE" {
            guard self.parentList.parentList == nil && self.parentList.peek(1) == nil else {
                throw TemplateError.invalidStructure(self, NSLocalizedString("Must be last element in template.", comment: ""))
            }
        } else {
            // Hnnn
            length = Int(self.type.suffix(3), radix: 16)!
            data = Data(count: length)
            self.setRowHeight()
        }
        self.width = 360
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
        self.rowHeight = (ceil(Double(length) / 24) * 17) + 5
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let remainder = reader.remainingBytes
        if self.type == "HEXD" || self.type == "CODE" {
            length = remainder
        }
        self.setRowHeight()
        if length > remainder {
            // Pad to expected length and throw error
            data = try reader.readData(length: remainder) + Data(count: length-remainder)
            throw BinaryDataReaderError.insufficientData
        } else {
            data = try reader.readData(length: length)
        }
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if let data = self.data {
            writer.data.append(data)
        } else {
            writer.advance(length)
        }
    }
}
