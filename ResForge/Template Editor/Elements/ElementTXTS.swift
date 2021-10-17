import RFSupport

// Implements TXTS, Tnnn
class ElementTXTS: ElementCSTR {
    override func configurePadding() {
        switch self.type {
        case "TXTS":
            padding = .none
        default:
            let nnn = Element.variableTypeValue(type)
            padding = .fixed(nnn)
            maxLength = nnn
        }
    }
    
    override func configure() throws {
        guard self.type != "TXTS" || self.isAtEnd() else {
            throw TemplateError.unboundedElement(self)
        }
        try super.configure()
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let end = reader.data[reader.position...].firstIndex(of: 0) ?? reader.data.endIndex
        let length = min(end - reader.position, maxLength)
        
        value = try reader.readString(length: length, encoding: .macOSRoman)
        try reader.advance(padding.length(length))
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }
        
        try? writer.writeString(value, encoding: .macOSRoman)
        writer.advance(padding.length(value.count))
    }
}
