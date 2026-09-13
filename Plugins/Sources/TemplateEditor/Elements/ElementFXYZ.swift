import Foundation
import RFSupport

class ElementFXYZ: CasedElement {
    static let fixed1 = Double(1 << 15)

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
            // The actual max value will be rounded up for display, so we should set
            // the min/max display values directly instead of trying to calculate them.
            formatter.minimum = -1
            formatter.maximum = 0.99997
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
