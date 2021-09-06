import Foundation
import RFSupport

// Implements FIXD and FRAC
class ElementFIXD: CaseableElement {
    static let fixed1 = 1 << 16
    static let fract1 = 1 << 30
    
    private let double1: Double
    private var intValue: Int32 = 0
    @objc private var value: NSNumber {
        get { Double(intValue) / double1 as NSNumber }
        set { intValue = Int32(round(newValue as! Double * double1)) }
    }
    
    required init(type: String, label: String, tooltip: String? = nil) {
        double1 = Double(type == "FIXD" ? Self.fixed1 : Self.fract1)
        super.init(type: type, label: label, tooltip: tooltip)
        self.width = 90
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        intValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(intValue)
    }
    
    override var formatter: Formatter? {
        if Element.sharedFormatters[type] == nil {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = false
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = type == "FIXD" ? 5 : 9
            formatter.minimum = Double(Int32.min) / double1 as NSNumber
            formatter.maximum = Double(Int32.max) / double1 as NSNumber
            formatter.nilSymbol = "\0"
            Element.sharedFormatters[type] = formatter
        }
        return Element.sharedFormatters[type]
    }
}
