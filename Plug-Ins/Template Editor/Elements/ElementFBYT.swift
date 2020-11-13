import RKSupport

// Implements FBYT, FWRD, FLNG, FLLG, Fnnn
class ElementFBYT: Element {
    let length: Int
    
    required init(type: String, label: String, tooltip: String? = nil) {
        switch type {
        case "FBYT":
            length = 1
        case "FWRD":
            length = 2
        case "FLNG":
            length = 4
        case "FLLG":
            length = 8
        default:
            length = Int(type.suffix(3), radix: 16)!
        }
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = false
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        try reader.advance(length)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.advance(length)
    }
}
