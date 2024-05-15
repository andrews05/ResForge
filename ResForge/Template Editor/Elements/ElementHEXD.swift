import AppKit
import RFSupport

// Implements HEXD, HEXS, Hnnn
class ElementHEXD: BaseElement {
    var data: Data?
    var length = 0

    override func configure() throws {
        if type == "HEXD" || type == "HEXS" || type == "CODE" {
            guard self.isAtEnd() else {
                throw TemplateError.unboundedElement(self)
            }
        } else {
            // Hnnn
            length = BaseElement.variableTypeValue(type)
            data = Data(count: length)
            self.setRowHeight()
        }
        width = 360
    }

    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 5
        frame.size.width = width - 4
        frame.size.height = CGFloat(rowHeight) - 9
        let textField = NSTextField(frame: frame)
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.font = NSFont.userFixedPitchFont(ofSize: 11)
        if let data {
            var count = 0
            textField.stringValue = data.map {
                count += 1
                return String(format: count.isMultiple(of: 4) ? "%02X " : "%02X", $0)
            } .joined()
        }
        view.addSubview(textField)
    }

    private func setRowHeight() {
        // 24 bytes per line, 13pt line height (minimum height 22)
        rowHeight = (ceil(Double(length) / 24) * 13) + 9
    }

    override func readData(from reader: BinaryDataReader) throws {
        let remainder = reader.bytesRemaining
        if type == "HEXD" || type == "HEXS" || type == "CODE" {
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
        if let data {
            writer.writeData(data)
        } else {
            writer.advance(length)
        }
    }
}
