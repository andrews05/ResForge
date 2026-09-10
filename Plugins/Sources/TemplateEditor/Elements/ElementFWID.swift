import Foundation
import RFSupport

class ElementFWID: CasedElement {
    static let fixed1 = Double(1 << 12)

    private var intValue: Int16 = 0
    @objc private var value: NSNumber {
        get { Double(intValue) / Self.fixed1 as NSNumber }
        set { intValue = Int16(round(newValue as! Double * Self.fixed1)) }
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
            formatter.minimum = Double(Int16.min) / Self.fixed1 as NSNumber
            formatter.maximum = Double(Int16.max) / Self.fixed1 as NSNumber
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
