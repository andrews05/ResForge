import RKSupport

class ElementCHAR: CaseableElement {
    private var charCode: UInt8 = 0
    @objc private var value: String {
        get {
            charCode == 0 ? "" : String(bytes: [charCode], encoding: .macOSRoman)!
        }
        set {
            charCode = newValue.data(using: .macOSRoman)?.first ?? 0
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        charCode = try reader.read()
    }
    
    override func dataSize(_ size: inout Int) {
        size += 1
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(charCode)
    }
    
    override class var formatter: Formatter? {
        let formatter = MacRomanFormatter()
        formatter.stringLength = 1
        formatter.exactLengthRequired = true
        return formatter
    }
}
