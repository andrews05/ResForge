import RKSupport

// Implements UBYT, UWRD, ULNG, ULLG
class ElementUWRD<T: FixedWidthInteger & UnsignedInteger>: CaseableElement {
    @objc var value: UInt = 0
    
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
        value = UInt(try reader.read() as T)
    }
    
    override func dataSize(_ size: inout Int) {
        size += T.bitWidth / 8
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(T(value))
    }
    
    override var formatter: Formatter? {
        if Element.sharedFormatters[type] == nil {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = true
            formatter.minimum = NSNumber(value: UInt(T.min))
            formatter.maximum = NSNumber(value: UInt(T.max))
            formatter.nilSymbol = "\0"
            Element.sharedFormatters[type] = formatter
        }
        return Element.sharedFormatters[type]
    }
}
