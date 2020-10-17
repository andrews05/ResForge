import RKSupport

class ElementTNAM: Element {
    var tnam: FourCharCode = 0
    @objc var value: String {
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
    
    override var formatter: Formatter? {
        if Element.sharedFormatters[type] == nil {
            let formatter = MacRomanFormatter()
            formatter.stringLength = 4
            formatter.exactLengthRequired = true
            Element.sharedFormatters[type] = formatter
        }
        return Element.sharedFormatters[type]
    }
    
}
