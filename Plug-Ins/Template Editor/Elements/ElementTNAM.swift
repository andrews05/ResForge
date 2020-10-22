import RKSupport

class ElementTNAM: CaseableElement {
    private var tnam: FourCharCode = 0
    // This is marked as dynamic so that RSID can bind to it and receive changes
    @objc dynamic private var value: String {
        get {
            tnam.stringValue
        }
        set {
            tnam = FourCharCode(newValue)
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tnam = try reader.read()
    }
    
    override func dataSize(_ size: inout Int) {
        size += 4
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tnam)
    }
    
    override class var formatter: Formatter? {
        let formatter = MacRomanFormatter()
        formatter.stringLength = 4
        formatter.exactLengthRequired = true
        return formatter
    }
}
