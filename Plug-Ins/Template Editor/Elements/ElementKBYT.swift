import Cocoa
import RKSupport

// Implement KBYT, KWRD, KLNG, KLLG
class ElementKBYT<T: FixedWidthInteger & SignedInteger>: KeyElement {
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
    
    override class var formatter: Formatter? {
        return ElementDBYT<T>.formatter
    }
}
