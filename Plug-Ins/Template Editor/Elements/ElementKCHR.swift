import RKSupport

class ElementKCHR: KeyElement {
    private var tValue: UInt8 = 0
    @objc private var value: String {
        get {
            tValue == 0 ? "" : String(bytes: [tValue], encoding: .macOSRoman)!
        }
        set {
            tValue = newValue.data(using: .macOSRoman)?.first ?? 0
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        _ = self.setCase(self.caseMap[value])
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override class var formatter: Formatter? {
        return ElementCHAR.formatter
    }
}
