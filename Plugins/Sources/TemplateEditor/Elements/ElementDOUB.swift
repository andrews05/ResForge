import Foundation
import RFSupport

class ElementDOUB: CasedElement {
    @objc private var value: Double = 0

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 6
    }

    override func readData(from reader: BinaryDataReader) throws {
        value = Double(bitPattern: try reader.read())
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }

    override var formatter: Formatter {
        self.sharedFormatter {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = false
            formatter.numberStyle = .scientific
            formatter.minimum = 0
            formatter.maximum = Double.greatestFiniteMagnitude as NSNumber
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
