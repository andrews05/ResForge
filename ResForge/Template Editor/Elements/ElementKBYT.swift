import Foundation
import RFSupport

// Implements KBYT, KWRD, KLNG, KQWD, KUBT, KUWD, KULG, KUQD
class ElementKBYT<T: FixedWidthInteger>: KeyElement {
    private var tValue: T = 0
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        _ = self.setCase(value)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override var formatter: Formatter {
        let key = T.isSigned ? "INT" : "UINT"
        return self.sharedFormatter("\(key)\(T.bitWidth)") { IntFormatter<T>() }
    }
}
