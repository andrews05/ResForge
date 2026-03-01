import Foundation
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=331

public struct ColorTable {
    static let device: UInt16 = 0x8000

    static func read(_ reader: BinaryDataReader) throws -> [RGBColor] {
        try reader.advance(4) // skip seed
        let flags = try reader.read() as UInt16
        let device = flags == Self.device
        let size = Int(try reader.read() as Int16) + 1
        // If size is zero, default to the system1 (monochrome) table
        if size == 0 {
            return Self.system1
        }
        guard 0...256 ~= size else {
            throw ImageReaderError.invalid
        }

        let data = try reader.readData(length: size * 8)
        var offset = data.startIndex
        var colors = Array(repeating: RGBColor(), count: 256)
        for i in 0..<size {
            // Take low byte for the value, ensuring high byte is 0
            guard device || data[offset] == 0 else {
                throw ImageReaderError.invalid
            }
            let value = device ? i : Int(data[offset + 1])
            // Take high bytes for the rgb
            colors[value] = RGBColor(red: data[offset + 2], green: data[offset + 4], blue: data[offset + 6])
            offset += 8
        }

        return colors
    }

    static func write(_ writer: BinaryDataWriter, colors: [RGBColor]) {
        writer.advance(6) // skip seed and flags
        writer.write(Int16(colors.count - 1))
        for (i, color) in colors.enumerated() {
            writer.write(Int16(i))
            writer.writeData(Data([color.red, color.red, color.green, color.green, color.blue, color.blue]))
        }
    }

    /// Get a system color table by clut id.
    public static func get(id: Int16) throws -> [RGBColor] {
        switch id {
        case 1, 33:
            return Self.system1
        case 2:
            return Self.system2
        case 4:
            return Self.system4
        case 8:
            return Self.system8
        case 34, 36, 40:
            // Synthesize a grayscale palette scaling from white to black
            let count = 1 << (id - 32)
            let step = 255 / (count - 1)
            return stride(from: 255, through: 0, by: -step).map { [$0, $0, $0] }
        default:
            // We don't have access to the EditorManager here so we can't lookup currently loaded clut resources
            // (In practice this is unlikely to be needed)
            throw ImageReaderError.unsupported
        }
    }
}


public struct RGBColor: Hashable, ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = UInt8
    public var red: UInt8 = 0
    public var green: UInt8 = 0
    public var blue: UInt8 = 0
    public var alpha: UInt8 = 0xFF
}

public extension RGBColor {
    /// Convenience initialiser for static color tables.
    init(arrayLiteral elements: UInt8...) {
        red = elements[0]
        green = elements[1]
        blue = elements[2]
    }

    /// Create a 24-bit RGBColor from an RGB555 byte pair.
    init(hi: UInt8, lo: UInt8) {
        red = (hi << 1) & 0xF8
        green = (hi << 6) | (lo >> 2) & 0xF8
        blue = lo << 3
        // Copy the upper 3 bits to the empty lower 3 bits
        red |= red >> 5
        green |= green >> 5
        blue |= blue >> 5
    }

    /// Draw the color to the bitmap as RGBA.
    func draw(to bitmap: inout UnsafeMutablePointer<UInt8>) {
        bitmap[0] = red
        bitmap[1] = green
        bitmap[2] = blue
        bitmap[3] = 0xFF
        bitmap += 4
    }

    func rgb555() -> UInt16 {
        UInt16(red & 0xF8) << 7 |
        UInt16(green & 0xF8) << 2 |
        UInt16(blue & 0xF8) >> 3
    }

    mutating func reduceTo555() {
        red = (red & 0xF8) | (red >> 5)
        green = (green & 0xF8) | (green >> 5)
        blue = (blue & 0xF8) | (blue >> 5)
        alpha = 0xFF
    }
}


public extension ColorTable {
    /// White & black palette, from clut id 1 in the Mac OS System file.
    static let system1: [RGBColor] = [
        [255, 255, 255],
        [0, 0, 0],
    ]

    /// Standard 4 color palette, from clut id 2 in the Mac OS System file.
    static let system2: [RGBColor] = [
        [255, 255, 255],
        [172, 172, 172],
        [85, 85, 85],
        [0, 0, 0],
    ]

    /// Standard 16 color palette, from clut id 4 in the Mac OS System file.
    static let system4: [RGBColor] = [
        [255, 255, 255],
        [252, 243, 5],
        [255, 100, 2],
        [221, 8, 6],
        [242, 8, 132],
        [70, 0, 165],
        [0, 0, 212],
        [2, 171, 234],
        [31, 183, 20],
        [0, 100, 17],
        [86, 44, 5],
        [144, 113, 58],
        [192, 192, 192],
        [128, 128, 128],
        [64, 64, 64],
        [0, 0, 0],
    ]

    /// Standard 256 color palette, from clut id 8 in the Mac OS System file.
    static let system8: [RGBColor] = [
        [255, 255, 255],
        [255, 255, 204],
        [255, 255, 153],
        [255, 255, 102],
        [255, 255, 51],
        [255, 255, 0],
        [255, 204, 255],
        [255, 204, 204],
        [255, 204, 153],
        [255, 204, 102],
        [255, 204, 51],
        [255, 204, 0],
        [255, 153, 255],
        [255, 153, 204],
        [255, 153, 153],
        [255, 153, 102],
        [255, 153, 51],
        [255, 153, 0],
        [255, 102, 255],
        [255, 102, 204],
        [255, 102, 153],
        [255, 102, 102],
        [255, 102, 51],
        [255, 102, 0],
        [255, 51, 255],
        [255, 51, 204],
        [255, 51, 153],
        [255, 51, 102],
        [255, 51, 51],
        [255, 51, 0],
        [255, 0, 255],
        [255, 0, 204],
        [255, 0, 153],
        [255, 0, 102],
        [255, 0, 51],
        [255, 0, 0],
        [204, 255, 255],
        [204, 255, 204],
        [204, 255, 153],
        [204, 255, 102],
        [204, 255, 51],
        [204, 255, 0],
        [204, 204, 255],
        [204, 204, 204],
        [204, 204, 153],
        [204, 204, 102],
        [204, 204, 51],
        [204, 204, 0],
        [204, 153, 255],
        [204, 153, 204],
        [204, 153, 153],
        [204, 153, 102],
        [204, 153, 51],
        [204, 153, 0],
        [204, 102, 255],
        [204, 102, 204],
        [204, 102, 153],
        [204, 102, 102],
        [204, 102, 51],
        [204, 102, 0],
        [204, 51, 255],
        [204, 51, 204],
        [204, 51, 153],
        [204, 51, 102],
        [204, 51, 51],
        [204, 51, 0],
        [204, 0, 255],
        [204, 0, 204],
        [204, 0, 153],
        [204, 0, 102],
        [204, 0, 51],
        [204, 0, 0],
        [153, 255, 255],
        [153, 255, 204],
        [153, 255, 153],
        [153, 255, 102],
        [153, 255, 51],
        [153, 255, 0],
        [153, 204, 255],
        [153, 204, 204],
        [153, 204, 153],
        [153, 204, 102],
        [153, 204, 51],
        [153, 204, 0],
        [153, 153, 255],
        [153, 153, 204],
        [153, 153, 153],
        [153, 153, 102],
        [153, 153, 51],
        [153, 153, 0],
        [153, 102, 255],
        [153, 102, 204],
        [153, 102, 153],
        [153, 102, 102],
        [153, 102, 51],
        [153, 102, 0],
        [153, 51, 255],
        [153, 51, 204],
        [153, 51, 153],
        [153, 51, 102],
        [153, 51, 51],
        [153, 51, 0],
        [153, 0, 255],
        [153, 0, 204],
        [153, 0, 153],
        [153, 0, 102],
        [153, 0, 51],
        [153, 0, 0],
        [102, 255, 255],
        [102, 255, 204],
        [102, 255, 153],
        [102, 255, 102],
        [102, 255, 51],
        [102, 255, 0],
        [102, 204, 255],
        [102, 204, 204],
        [102, 204, 153],
        [102, 204, 102],
        [102, 204, 51],
        [102, 204, 0],
        [102, 153, 255],
        [102, 153, 204],
        [102, 153, 153],
        [102, 153, 102],
        [102, 153, 51],
        [102, 153, 0],
        [102, 102, 255],
        [102, 102, 204],
        [102, 102, 153],
        [102, 102, 102],
        [102, 102, 51],
        [102, 102, 0],
        [102, 51, 255],
        [102, 51, 204],
        [102, 51, 153],
        [102, 51, 102],
        [102, 51, 51],
        [102, 51, 0],
        [102, 0, 255],
        [102, 0, 204],
        [102, 0, 153],
        [102, 0, 102],
        [102, 0, 51],
        [102, 0, 0],
        [51, 255, 255],
        [51, 255, 204],
        [51, 255, 153],
        [51, 255, 102],
        [51, 255, 51],
        [51, 255, 0],
        [51, 204, 255],
        [51, 204, 204],
        [51, 204, 153],
        [51, 204, 102],
        [51, 204, 51],
        [51, 204, 0],
        [51, 153, 255],
        [51, 153, 204],
        [51, 153, 153],
        [51, 153, 102],
        [51, 153, 51],
        [51, 153, 0],
        [51, 102, 255],
        [51, 102, 204],
        [51, 102, 153],
        [51, 102, 102],
        [51, 102, 51],
        [51, 102, 0],
        [51, 51, 255],
        [51, 51, 204],
        [51, 51, 153],
        [51, 51, 102],
        [51, 51, 51],
        [51, 51, 0],
        [51, 0, 255],
        [51, 0, 204],
        [51, 0, 153],
        [51, 0, 102],
        [51, 0, 51],
        [51, 0, 0],
        [0, 255, 255],
        [0, 255, 204],
        [0, 255, 153],
        [0, 255, 102],
        [0, 255, 51],
        [0, 255, 0],
        [0, 204, 255],
        [0, 204, 204],
        [0, 204, 153],
        [0, 204, 102],
        [0, 204, 51],
        [0, 204, 0],
        [0, 153, 255],
        [0, 153, 204],
        [0, 153, 153],
        [0, 153, 102],
        [0, 153, 51],
        [0, 153, 0],
        [0, 102, 255],
        [0, 102, 204],
        [0, 102, 153],
        [0, 102, 102],
        [0, 102, 51],
        [0, 102, 0],
        [0, 51, 255],
        [0, 51, 204],
        [0, 51, 153],
        [0, 51, 102],
        [0, 51, 51],
        [0, 51, 0],
        [0, 0, 255],
        [0, 0, 204],
        [0, 0, 153],
        [0, 0, 102],
        [0, 0, 51],
        [238, 0, 0],
        [221, 0, 0],
        [187, 0, 0],
        [170, 0, 0],
        [136, 0, 0],
        [119, 0, 0],
        [85, 0, 0],
        [68, 0, 0],
        [34, 0, 0],
        [17, 0, 0],
        [0, 238, 0],
        [0, 221, 0],
        [0, 187, 0],
        [0, 170, 0],
        [0, 136, 0],
        [0, 119, 0],
        [0, 85, 0],
        [0, 68, 0],
        [0, 34, 0],
        [0, 17, 0],
        [0, 0, 238],
        [0, 0, 221],
        [0, 0, 187],
        [0, 0, 170],
        [0, 0, 136],
        [0, 0, 119],
        [0, 0, 85],
        [0, 0, 68],
        [0, 0, 34],
        [0, 0, 17],
        [238, 238, 238],
        [221, 221, 221],
        [187, 187, 187],
        [170, 170, 170],
        [136, 136, 136],
        [119, 119, 119],
        [85, 85, 85],
        [68, 68, 68],
        [34, 34, 34],
        [17, 17, 17],
        [0, 0, 0],
    ]
}
