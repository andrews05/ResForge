import RFSupport

// Implements TXTS, Tnnn
class ElementTXTS: ElementCSTR {
    override func configurePadding() throws {
        switch self.type {
        case "TXTS":
            guard self.isAtEnd() else {
                throw TemplateError.unboundedElement(self)
            }
            padding = .none
        default:
            let nnn = Element.variableTypeValue(type)
            padding = .fixed(nnn)
            maxLength = nnn
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let length = min(reader.remainingBytes, maxLength)
        
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
