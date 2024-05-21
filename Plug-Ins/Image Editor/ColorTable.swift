import RFSupport
import OrderedCollections

struct ColorTable {
    static let device: UInt16 = 0x8000
    static let monochrome = [RGBColor(red: 255, green: 255, blue: 255), RGBColor(red: 0, green: 0, blue: 0)]

    static func read(_ reader: BinaryDataReader) throws -> [RGBColor] {
        try reader.advance(4) // skip seed
        let flags = try reader.read() as UInt16
        let device = flags == Self.device
        let size = Int(try reader.read() as Int16) + 1
        guard 0...256 ~= size else {
            throw ImageReaderError.invalidData
        }

        let data = try reader.readData(length: size * 8)
        var offset = data.startIndex
        var colors = Array(repeating: RGBColor(), count: 256)
        for i in 0..<size {
            // Take low byte for the value, ensuring high byte is 0
            guard device || data[offset] == 0 else {
                throw ImageReaderError.invalidData
            }
            let value = device ? i : Int(data[offset + 1])
            // Take high bytes for the rgb
            colors[value] = RGBColor(red: data[offset + 2], green: data[offset + 4], blue: data[offset + 6])
            offset += 8
        }

        return colors
    }

    static func write(_ writer: BinaryDataWriter, colors: OrderedSet<UInt32>) {
        writer.advance(6) // skip seed and flags
        writer.write(Int16(colors.count - 1))
        for (i, color) in colors.enumerated() {
            // Use the raw bytes of the UInt32
            withUnsafeBytes(of: color) {
                writer.write(Int16(i))
                writer.writeData(Data([$0[0], $0[0], $0[1], $0[1], $0[2], $0[2]]))
            }
        }
    }
}

struct RGBColor: Hashable {
    var red: UInt8 = 0
    var green: UInt8 = 0
    var blue: UInt8 = 0
}

extension RGBColor {
    /// Create a 24-bit RGBColor from a 16-bit RGB555 byte pair.
    init(_ hi: UInt8, _ lo: UInt8) {
        red = (hi << 1) & 0xF8
        green = (hi << 6) | (lo >> 2) & 0xF8
        blue = lo << 3
        // Copy the upper 3 bits to the empty lower 3 bits
        red |= red >> 5
        green |= green >> 5
        blue |= blue >> 5
    }

    func draw(to bitmap: inout UnsafeMutablePointer<UInt8>) {
        bitmap[0] = red
        bitmap[1] = green
        bitmap[2] = blue
        bitmap[3] = 0xFF
    }
}
