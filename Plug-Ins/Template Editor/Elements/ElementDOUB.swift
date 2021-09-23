import Foundation
import RFSupport

class ElementDOUB: ComboElement {
    @objc private var value: Double = 0
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        self.width = 180
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = Double(bitPattern: try reader.read())
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.hasThousandSeparators = false
        formatter.numberStyle = .scientific
        formatter.minimum = 0
        formatter.maximum = Double.greatestFiniteMagnitude as NSNumber
        formatter.nilSymbol = "\0"
        return formatter
    }
}
