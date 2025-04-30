import AppKit
import RFSupport

// Implements BHEX, WHEX, LHEX, BSHX, WSHX, LSHX
class ElementBHEX<T: FixedWidthInteger & UnsignedInteger>: BaseElement {
    private var data = Data()
    private var length = 0
    private var skipLengthBytes = false
    private var lengthBytes = 0

    override func configure() throws {
        skipLengthBytes = type.hasSuffix("SHX")
        lengthBytes = T.bitWidth / 8
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
        var count = 0
        textField.stringValue = data.map {
            count += 1
            return String(format: count.isMultiple(of: 4) ? "%02X " : "%02X", $0)
        } .joined()
        view.addSubview(textField)
    }

    private func setRowHeight() {
        // 24 bytes per line, 13pt line height (minimum height 22)
        let lines = max(ceil(Double(length) / 24), 1)
        rowHeight = (lines * 13) + 9
    }

    override func readData(from reader: BinaryDataReader) throws {
        length = Int(try reader.read() as T)
        if skipLengthBytes {
            guard length >= lengthBytes else {
                throw TemplateError.dataMismatch(self)
            }
            length -= lengthBytes
        }
        self.setRowHeight()
        let remainder = reader.bytesRemaining
        if length > remainder {
            // Pad to expected length and throw error
            data = try reader.readData(length: remainder) + Data(count: length-remainder)
            throw BinaryDataReaderError.insufficientData
        } else {
            data = try reader.readData(length: length)
        }
    }

    override func writeData(to writer: BinaryDataWriter) {
        var writeLength = length
        if skipLengthBytes {
            writeLength += lengthBytes
        }
        writer.write(T(writeLength))
        writer.writeData(data)
    }
}
