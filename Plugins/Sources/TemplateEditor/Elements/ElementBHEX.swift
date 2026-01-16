import RFSupport

// Implements BHEX, WHEX, LHEX, BSHX, WSHX, LSHX
class ElementBHEX<T: FixedWidthInteger & UnsignedInteger>: ElementHEXD {
    private var skipLengthBytes = false
    private var lengthBytes = 0

    override func configure() throws {
        skipLengthBytes = type.hasSuffix("SHX")
        lengthBytes = T.bitWidth / 8
        blockWidth = 12
    }

    override func readData(from reader: BinaryDataReader) throws {
        length = Int(try reader.read() as T)
        if skipLengthBytes {
            guard length >= lengthBytes else {
                throw TemplateError.dataMismatch(self)
            }
            length -= lengthBytes
        }
        try super.readData(from: reader)
    }

    override func writeData(to writer: BinaryDataWriter) {
        var writeLength = length
        if skipLengthBytes {
            writeLength += lengthBytes
        }
        writer.write(T(writeLength))
        super.writeData(to: writer)
    }
}
