import RKSupport

class ElementTNAM: CaseableElement {
    // This is marked as dynamic so that RSID can bind to it and receive changes
    @objc dynamic private var value: String = ""
    
    override func readData(from reader: BinaryDataReader) throws {
        value = (try reader.read() as FourCharCode).stringValue
    }
    
    override func dataSize(_ size: inout Int) {
        size += 4
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(FourCharCode(value))
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
