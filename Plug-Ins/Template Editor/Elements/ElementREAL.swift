import Foundation
import RFSupport

class ElementREAL: CaseableElement {
    @objc private var value: Float = 0
    
    required init(type: String, label: String, tooltip: String? = nil) {
        super.init(type: type, label: label, tooltip: tooltip)
        self.width = 90
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = Float(bitPattern: try reader.read())
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.hasThousandSeparators = false
        formatter.numberStyle = .scientific
        formatter.maximumSignificantDigits = 7
        formatter.minimum = 0
        formatter.maximum = Float.greatestFiniteMagnitude as NSNumber
        formatter.nilSymbol = "\0"
        return formatter
    }
}
