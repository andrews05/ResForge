import RKSupport

// Implements BHEX, WHEX, LHEX, BSHX, WSHX, LSHX
class ElementBHEX<T: FixedWidthInteger & UnsignedInteger>: ElementHEXD {
    private var skipLengthBytes = false
    private var lengthBytes = 0
    
    override func configure() throws {
        skipLengthBytes = self.type.dropFirst().first == "S"
        lengthBytes = T.bitWidth / 8
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        length = Int(try reader.read() as T)
        if skipLengthBytes {
            length = max(length-lengthBytes, 0)
        }
        data = try reader.readData(length: length)
    }
    
    override func dataSize(_ size: inout Int) {
        size += length + lengthBytes
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        var writeLength = length
        if skipLengthBytes {
            writeLength += lengthBytes
        }
        writer.write(T(writeLength))
        if let data = data {
            writer.data.append(data)
        } else {
            writer.advance(length)
        }
    }
}
