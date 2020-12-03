import RKSupport

// Implements DBYT, DWRD, DLNG, DLLG, UBYT, UWRD, ULNG, ULLG
class ElementDBYT<T: FixedWidthInteger>: RangeableElement {
    var tValue: T = 0
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }
    
    override func configure() throws {
        switch T.bitWidth/8 {
        case 4:
            self.width = 90
        case 8:
            self.width = 120
        default:
            break
        }
        try super.configure()
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.hasThousandSeparators = true
        formatter.minimum = T.min as? NSNumber
        formatter.maximum = T.max as? NSNumber
        formatter.allowsFloats = false
        formatter.nilSymbol = "\0"
        return formatter
    }
}
