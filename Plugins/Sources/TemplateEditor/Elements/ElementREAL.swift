import Foundation
import RFSupport

class ElementREAL: CasedElement {
    @objc private var value: Float = 0

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 3
    }

    override func readData(from reader: BinaryDataReader) throws {
        value = Float(bitPattern: try reader.read())
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }

    override var formatter: Formatter {
        self.sharedFormatter { FloatFormatter<Float>() }
    }
}
