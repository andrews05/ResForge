import RKSupport

class ElementKTYP: KeyElement {
    private var tValue: UInt32 = 0
    @objc private var value: String {
        get { tValue.stringValue }
        set { tValue = FourCharCode(newValue) }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        _ = self.setCase(self.caseMap[value])
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override class var formatter: Formatter? {
        return ElementTNAM.formatter
    }
}
