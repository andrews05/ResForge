import Foundation
import RFSupport

// Implements KBYT, KWRD, KLNG, KLLG, KUBT, KUWD, KULG, KULL
class ElementKBYT<T: FixedWidthInteger>: KeyElement {
    private var tValue: T = 0
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        _ = self.setCase(self.caseMap[value])
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override class var formatter: Formatter? {
        return ElementDBYT<T>.formatter
    }
}
