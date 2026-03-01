import AppKit
import RFSupport

// https://wiki.multimedia.cx/index.php/Apple_RPZA

/// Decoder for the QuickTime "rpza" (Road Pizza) compressor.
struct QTVideo {
    private let rep: NSBitmapImageRep
    private let rowBytes: Int
    private let input: UnsafeRawBufferPointer
    private let output: UnsafeMutablePointer<UInt8>
    private var inPos = 0
    private var x = 0
    private var y = 0
    private var y2: Int

    static func rep(for imageDesc: QTImageDesc, reader: BinaryDataReader) throws -> NSBitmapImageRep {
        try reader.advance(imageDesc.bytesUntilData)

        // Round the width up to a multiple of 4 to calculate row bytes
        // This means we don't need to check for partial-width blocks while decoding
        let rowBytes = (Int(imageDesc.width + 3) & ~3) * 3
        // Initialise the rep
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(imageDesc.width),
                                   pixelsHigh: Int(imageDesc.height),
                                   bitsPerSample: 8,
                                   samplesPerPixel: 3,
                                   hasAlpha: false,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: rowBytes,
                                   bitsPerPixel: 0)!

        // First byte is ignored, chunk size is next 3 bytes
        let chunkSize = Int(try reader.read() as UInt32) & 0xFFFFFF
        guard chunkSize >= 4 else {
            throw ImageReaderError.invalid
        }
        let data = try reader.readData(length: chunkSize - 4)
        try data.withUnsafeBytes { input in
            var video = Self(rep: rep, input: input)
            try video.decode()
        }

        return rep
    }

    private init(rep: NSBitmapImageRep, input: UnsafeRawBufferPointer) {
        self.rep = rep
        rowBytes = rep.bytesPerRow // This is a computed property, only access it once.
        self.input = input
        output = rep.bitmapData!
        y2 = min(4, rep.pixelsHigh)
    }

    private mutating func decode() throws {
        while inPos < input.count {
            let op = input.load(fromByteOffset: inPos, as: UInt8.self)
            if op & 0x80 == 0 {
                // "Special" opcode - peek two bytes ahead to determine block type
                guard input.count - inPos > 2 else {
                    throw ImageReaderError.invalid
                }
                let next = input.load(fromByteOffset: inPos + 2, as: UInt8.self)
                if next & 0x80 == 0 {
                    // 16 colours
                    guard input.count - inPos >= 32 else {
                        throw ImageReaderError.invalid
                    }
                    self.uncompressedBlock()
                } else {
                    // Four colour palette
                    guard input.count - inPos >= 8 else {
                        throw ImageReaderError.invalid
                    }
                    let palette = self.loadPalette()
                    self.paletteBlock(palette: palette)
                }
            } else {
                let blockCount = Int(op & 0x1F) + 1
                guard x + blockCount * 12 <= rowBytes else {
                    throw ImageReaderError.invalid
                }
                inPos += 1
                let code = op & 0xE0
                switch code {
                case 0x80:
                    // Skip blocks
                    x += blockCount * 12
                case 0xA0:
                    // Single colour
                    guard input.count - inPos >= 2 else {
                        throw ImageReaderError.invalid
                    }
                    let color = self.loadColor()
                    for _ in 0..<blockCount {
                        self.solidBlock(color: color)
                    }
                case 0xC0:
                    // Four colour palette
                    guard input.count - inPos >= 4 + (4 * blockCount) else {
                        throw ImageReaderError.invalid
                    }
                    let palette = self.loadPalette()
                    for _ in 0..<blockCount {
                        self.paletteBlock(palette: palette)
                    }
                default:
                    // 0xE0 = no-op?
                    break
                }
            }

            if x == rowBytes {
                if inPos == input.count {
                    // Decoding complete
                    break
                }
                // Move down to the next row of blocks
                x = 0
                y += 4
                guard y < rep.pixelsHigh else {
                    throw ImageReaderError.invalid
                }
                y2 = min(y + 4, rep.pixelsHigh)
            }
        }
    }

    private mutating func loadColor() -> RGBColor {
        let hi = input.load(fromByteOffset: inPos, as: UInt8.self)
        let lo = input.load(fromByteOffset: inPos + 1, as: UInt8.self)
        inPos += 2
        return RGBColor(hi: hi, lo: lo)
    }

    private func blendColors(_ a: RGBColor, _ b: RGBColor) -> RGBColor {
        // Note: We perform this calculation in 8-bits per channel while the original QuickTime
        // implementation operated in 5-bits. This means the decoded result will not be 100%
        // identical to that of QuickTime. However, as this is a lossy codec, slight variations
        // are acceptable - the higher depth we use here may even be considered more accurate.
        return RGBColor(red: UInt8((11 * Int(a.red) + 21 * Int(b.red)) / 32),
                        green: UInt8((11 * Int(a.green) + 21 * Int(b.green)) / 32),
                        blue: UInt8((11 * Int(a.blue) + 21 * Int(b.blue)) / 32))
    }

    private mutating func loadPalette() -> [RGBColor] {
        let colorA = self.loadColor()
        let colorB = self.loadColor()
        return [
            colorB,
            self.blendColors(colorA, colorB),
            self.blendColors(colorB, colorA),
            colorA,
        ]
    }

    private mutating func uncompressedBlock() {
        for by in y..<y2 {
            for bx in stride(from: x, to: x + 12, by: 3) {
                let color = self.loadColor()
                output[by * rowBytes + bx] = color.red
                output[by * rowBytes + bx + 1] = color.green
                output[by * rowBytes + bx + 2] = color.blue
            }
        }
        // Skip over any colours that we didn't read
        inPos += (y + 4 - y2) * 8
        x += 12
    }

    private mutating func paletteBlock(palette: [RGBColor]) {
        let block = UInt32(bigEndian: input.loadUnaligned(fromByteOffset: inPos, as: UInt32.self))
        inPos += 4
        var shift = 32
        for by in y..<y2 {
            for bx in stride(from: x, to: x + 12, by: 3) {
                shift -= 2
                let color = palette[Int(block >> shift & 0x3)]
                output[by * rowBytes + bx] = color.red
                output[by * rowBytes + bx + 1] = color.green
                output[by * rowBytes + bx + 2] = color.blue
            }
        }
        x += 12
    }

    private mutating func solidBlock(color: RGBColor) {
        for by in y..<y2 {
            for bx in stride(from: x, to: x + 12, by: 3) {
                output[by * rowBytes + bx] = color.red
                output[by * rowBytes + bx + 1] = color.green
                output[by * rowBytes + bx + 2] = color.blue
            }
        }
        x += 12
    }
}
