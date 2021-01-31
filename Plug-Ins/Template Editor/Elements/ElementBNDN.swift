import RKSupport

// Implements BNDN, LNDN
class ElementBNDN: Element {
    private let bigEndian: Bool
    
    required init!(type: String, label: String, tooltip: String? = nil) {
        bigEndian = type == "BNDN"
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = false
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        reader.bigEndian = self.bigEndian
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.bigEndian = self.bigEndian
    }
}
