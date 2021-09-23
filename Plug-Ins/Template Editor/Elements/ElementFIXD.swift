import Foundation
import RFSupport

class ElementFIXD: ComboElement {
    static let fixed1 = Double(1 << 16)
    
    private var intValue: Int32 = 0
    @objc private var value: NSNumber {
        get { Double(intValue) / Self.fixed1 as NSNumber }
        set { intValue = Int32(round(newValue as! Double * Self.fixed1)) }
    }
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        self.width = 90
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        intValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(intValue)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.hasThousandSeparators = false
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 5
        formatter.minimum = Double(Int32.min) / Self.fixed1 as NSNumber
        formatter.maximum = Double(Int32.max) / Self.fixed1 as NSNumber
        formatter.nilSymbol = "\0"
        return formatter
    }
}
