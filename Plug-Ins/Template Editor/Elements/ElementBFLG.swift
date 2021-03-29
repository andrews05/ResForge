import RFSupport

// Implements BFLG, WFLG, LFLG
class ElementBFLG<T: FixedWidthInteger & UnsignedInteger>: ElementBOOL {
    var tValue: T = 0
    @objc private var value: Bool {
        get { tValue != 0 }
        set { tValue = newValue ? 1 : 0 }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
}
