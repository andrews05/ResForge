import RFSupport

// Implements PSTR, BSTR, WSTR, LSTR, OSTR, ESTR, Pnnn
class ElementPSTR<T: FixedWidthInteger & UnsignedInteger>: ElementCSTR {
    override func configurePadding() throws {
        switch self.type {
        case "PSTR", "BSTR", "WSTR", "LSTR":
            padding = .none
        case "OSTR":
            padding = .odd
        case "ESTR":
            padding = .even
        default:
            let nnn = Element.variableTypeValue(type)
            padding = .fixed(nnn)
            maxLength = min(nnn-1, maxLength)
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let length = min(Int(try reader.read() as T), maxLength)
        guard length <= reader.remainingBytes else {
            throw TemplateError.dataMismatch(self)
        }
        
        if length > 0 {
            value = try reader.readString(length: length, encoding: .macOSRoman)
        }
        
        try self.readPadding(from: reader, length: length + T.bitWidth/8)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }
        
        let length = value.count
        writer.write(T(length))
        try? writer.writeString(value, encoding: .macOSRoman)
        
        self.writePadding(to: writer, length: length + T.bitWidth/8)
    }
}
