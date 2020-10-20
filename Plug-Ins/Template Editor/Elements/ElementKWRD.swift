import Cocoa
import RKSupport

// Implement KBYT, KWRD, KLNG, KLLG
class ElementKWRD<T: FixedWidthInteger & SignedInteger>: KeyElement {
    @objc private var value: Int = 0
    
    override func readData(from reader: BinaryDataReader) throws {
        value = Int(try reader.read() as T)
        _ = self.setCase(self.transformedValue(value) as? ElementCASE)
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
            formatter.minimum = NSNumber(value: Int(T.min))
            formatter.maximum = NSNumber(value: Int(T.max))
            formatter.nilSymbol = "\0"
            Element.sharedFormatters[type] = formatter
        }
        return Element.sharedFormatters[type]
    }
}
