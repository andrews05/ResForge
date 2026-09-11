import Foundation
import RFSupport

class ElementUNIV: ElementEXTN {
    @objc private var value: Float80 = 0

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 6
    }

    override func readData(from reader: BinaryDataReader) throws {
		try reader.advance(2)
        try super.readData(from: reader)
    }

    override func writeData(to writer: BinaryDataWriter) {
		// Pad with a clone of the exponent and sign bits
        var exponent = UInt16(value.exponentBitPattern)
        if value.sign == FloatingPointSign.minus {
            exponent &= 0x8000
        }
        writer.write(exponent)
        super.writeData(to: writer)
    }
}
