import Foundation
import RFSupport

class ElementSFRC: CasedElement {
    static let fixed1 = Double(1 << 16)

    private var intValue: UInt16 = 0
    @objc private var value: NSNumber {
        get { Double(intValue) / Self.fixed1 as NSNumber }
        set { intValue = UInt16(round(newValue as! Double * Self.fixed1)) }
    }

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 3
    }

    override func readData(from reader: BinaryDataReader) throws {
        intValue = try reader.read()
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(intValue)
    }

    override var formatter: Formatter {
        self.sharedFormatter {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = false
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 5
            formatter.minimum = 0
            formatter.maximum = Double(UInt16.max) / Self.fixed1 as NSNumber
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
