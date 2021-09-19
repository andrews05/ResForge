import Foundation
import RFSupport

// Implements DBYT, DWRD, DLNG, DLLG, UBYT, UWRD, ULNG, ULLG
class ElementDBYT<T: FixedWidthInteger>: RangeableElement {
    var tValue: T = 0
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        switch T.bitWidth/8 {
        case 4:
            self.width = 90
        case 8:
            self.width = 150
        default:
            break
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.minimum = T.min as? NSNumber
        formatter.maximum = T.max as? NSNumber
        formatter.allowsFloats = false
        formatter.nilSymbol = "\0"
        return formatter
    }
}
