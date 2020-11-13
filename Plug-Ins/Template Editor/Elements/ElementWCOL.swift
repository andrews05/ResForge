import RKSupport

// Implements WCOL, LCOL
class ElementWCOL<T: FixedWidthInteger & UnsignedInteger>: ElementCOLR {
    private var bits = 0
    
    override func configure() throws {
        switch T.bitWidth {
        case 16:
            // 15-bit colour
            bits = 5
        case 32:
            // 24-bit colour 00RRGGBB
            bits = 8
        default:
            break
        }
        mask = (1 << bits) - 1
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let tmp = UInt(try reader.read() as T)
        r = UInt16(tmp >> (bits*2) & mask)
        g = UInt16(tmp >> bits & mask)
        b = UInt16(tmp & mask)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        var tmp: T = 0
        tmp |= T(r) << (bits*2)
        tmp |= T(g) << bits
        tmp |= T(b)
        writer.write(tmp)
    }
}
