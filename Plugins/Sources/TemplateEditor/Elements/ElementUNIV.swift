import Foundation
import RFSupport

class ElementUNIV: ElementEXTN {
    @objc private var value: Float80 = 0

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 6
    }

    override func readData(from reader: BinaryDataReader) throws {
        try super.readData(from: reader)
        try reader.advance(2)
    }

    override func writeData(to writer: BinaryDataWriter) {
        super.writeData(to: writer)
        writer.write(Int16(0))
    }
}
