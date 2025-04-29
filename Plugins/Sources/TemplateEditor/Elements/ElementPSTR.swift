import RFSupport

// Implements PSTR, BSTR, WSTR, LSTR, OSTR, ESTR, Pnnn
class ElementPSTR<T: FixedWidthInteger & UnsignedInteger>: ElementCSTR {
    override func configurePadding() {
        maxLength = Int(T.max)
        switch type {
        case "PSTR", "BSTR", "WSTR", "LSTR":
            padding = .none
        case "OSTR":
            padding = .odd
        case "ESTR":
            padding = .even
        default:
            let nnn = BaseElement.variableTypeValue(type)
            padding = .fixed(nnn)
            maxLength = min(nnn-1, maxLength)
        }
    }

    override func readData(from reader: BinaryDataReader) throws {
        let length = min(Int(try reader.read() as T), maxLength)
        guard length <= reader.bytesRemaining else {
            throw TemplateError.dataMismatch(self)
        }

        value = try reader.readString(length: length, encoding: .macOSRoman)
        try reader.advance(padding.length(length + T.bitWidth/8))
    }

    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }

        writer.write(T(value.count))
        try? writer.writeString(value, encoding: .macOSRoman)
        writer.advance(padding.length(value.count + T.bitWidth/8))
    }
}
