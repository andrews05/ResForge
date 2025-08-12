import AppKit
import RFSupport

// https://wiki.multimedia.cx/index.php/Apple_SMC

/// Decoder for the QuickTime "smc " compressor.
struct QTGraphics {
    // Circular cache
    struct Cache {
        private var values: [UnsafePointer<UInt8>]
        private var nextPos = 0
        init(initialValue: UnsafePointer<UInt8>) {
            values = Array(repeating: initialValue, count: 256)
        }
        mutating func push(_ value: UnsafePointer<UInt8>) {
            values[nextPos] = value
            nextPos = (nextPos + 1) % 256
        }
        subscript(index: UInt8) -> UnsafePointer<UInt8> {
            values[Int(index)]
        }
    }

    private var inPos: UnsafePointer<UInt8>
    private let inputEnd: UnsafePointer<UInt8>
    private var outPos: UnsafeMutablePointer<UInt8>
    private let outputStart: UnsafeMutablePointer<UInt8>
    private let outputEnd: UnsafeMutablePointer<UInt8>
    private var cache2: Cache
    private var cache4: Cache
    private var cache8: Cache

    static func rep(for imageDesc: QTImageDesc, reader: BinaryDataReader) throws -> NSBitmapImageRep {
        try reader.advance(imageDesc.bytesUntilData)

        let width = Int(imageDesc.width)
        let height = Int(imageDesc.height)
        // Round the dimensions up to a multiple of 4
        // This means we don't need to check for partial blocks while decoding
        let roundedWidth = (width + 3) & ~3
        let roundedHeight = (height + 3) & ~3

        // First byte is ignored, chunk size is next 3 bytes
        let chunkSize = Int(try reader.read() as UInt32) & 0xFFFFFF
        guard chunkSize >= 4, let palette = imageDesc.colorTable else {
            throw ImageReaderError.invalid
        }
        let data = try reader.readData(length: chunkSize - 4)
        var pixelData = Data(repeating: 0, count: roundedWidth * roundedHeight)
        try pixelData.withUnsafeMutableBytes { outData in
            try outData.withMemoryRebound(to: UInt8.self) { output in
                try data.withUnsafeBytes { inData in
                    try inData.withMemoryRebound(to: UInt8.self) { input in
                        var graphics = Self(input: input, output: output)
                        try graphics.decode()
                    }
                }
            }
        }

        // Initialise the rep
        let rowBytes = roundedWidth * 3
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 3,
                                   hasAlpha: false,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: rowBytes,
                                   bitsPerPixel: 0)!
        let bitmap = rep.bitmapData!

        // Use the palette to draw the 4x4 blocks to the rep
        for y in stride(from: 0, to: roundedHeight, by: 4) {
            let y2 = min(y + 4, height)
            for x in stride(from: 0, to: rowBytes, by: 12) {
                var offset = y * roundedWidth + x / 12 * 16
                for by in y..<y2 {
                    for bx in stride(from: x, to: x + 12, by: 3) {
                        let index = Int(pixelData[offset])
                        guard index < palette.endIndex else {
                            throw ImageReaderError.invalid
                        }
                        offset += 1
                        let color = palette[index]
                        bitmap[by * rowBytes + bx] = color.red
                        bitmap[by * rowBytes + bx + 1] = color.green
                        bitmap[by * rowBytes + bx + 2] = color.blue
                    }
                }
            }
        }

        return rep
    }

    private init(input: UnsafeBufferPointer<UInt8>, output: UnsafeMutableBufferPointer<UInt8>) {
        inPos = input.baseAddress!
        inputEnd = inPos + input.count
        outPos = output.baseAddress!
        outputStart = outPos
        outputEnd = outPos + output.count
        cache2 = Cache(initialValue: inPos)
        cache4 = Cache(initialValue: inPos)
        cache8 = Cache(initialValue: inPos)
    }

    private mutating func decode() throws {
        while inPos < inputEnd {
            let op = inPos.pointee
            inPos += 1
            let code = op & 0xF0
            var blockCount: Int
            if code < 0x80 && (code & 0x10 != 0) {
                // Block count is next byte
                guard inputEnd - inPos >= 1 else {
                    throw ImageReaderError.invalid
                }
                blockCount = Int(inPos.pointee) + 1
                inPos += 1
            } else {
                // Block count is the lower 4 bits
                blockCount = Int(op & 0x0F) + 1
            }
            guard outputEnd - outPos >= blockCount * 16 else {
                throw ImageReaderError.invalid
            }
            switch code {
            case 0x00, 0x10:
                // Skip blocks
                outPos += blockCount * 16
            case 0x20, 0x30, 0x40, 0x50:
                // Repeat previous 1 or 2 blocks
                let bytes = code < 0x40 ? 16 : 32
                guard outputStart + bytes <= outPos, outputEnd - outPos >= blockCount * bytes else {
                    throw ImageReaderError.invalid
                }
                for _ in 0..<blockCount {
                    outPos.update(from: outPos - bytes, count: bytes)
                    outPos += bytes
                }
            case 0x60, 0x70:
                // Single colour
                guard inputEnd - inPos >= 1 else {
                    throw ImageReaderError.invalid
                }
                let val = inPos.pointee
                inPos += 1
                if val != 0 {
                    outPos.update(repeating: val, count: blockCount * 16)
                }
                outPos += blockCount * 16
            case 0x80:
                // 2 colours
                guard inputEnd - inPos >= 2 + blockCount * 2 else {
                    throw ImageReaderError.invalid
                }
                let values = inPos
                inPos += 2
                cache2.push(values)
                self.decode2(blockCount: blockCount, values: values)
            case 0x90:
                // 2 colours from cache
                guard inputEnd - inPos >= 1 + blockCount * 2 else {
                    throw ImageReaderError.invalid
                }
                let values = cache2[inPos.pointee]
                inPos += 1
                self.decode2(blockCount: blockCount, values: values)
            case 0xA0:
                // 4 colours
                guard inputEnd - inPos >= 4 + blockCount * 2 else {
                    throw ImageReaderError.invalid
                }
                let values = inPos
                inPos += 4
                cache4.push(values)
                self.decode4(blockCount: blockCount, values: values)
            case 0xB0:
                // 4 colours from cache
                guard inputEnd - inPos >= 1 + blockCount * 2 else {
                    throw ImageReaderError.invalid
                }
                let values = cache4[inPos.pointee]
                inPos += 1
                self.decode4(blockCount: blockCount, values: values)
            case 0xC0:
                // 8 colours
                guard inputEnd - inPos >= 8 + blockCount * 6 else {
                    throw ImageReaderError.invalid
                }
                let values = inPos
                inPos += 8
                cache8.push(values)
                self.decode8(blockCount: blockCount, values: values)
            case 0xD0:
                // 8 colours from cache
                guard inputEnd - inPos >= 1 + blockCount * 6 else {
                    throw ImageReaderError.invalid
                }
                let values = cache8[inPos.pointee]
                inPos += 1
                self.decode8(blockCount: blockCount, values: values)
            case 0xE0:
                // 16 colours
                guard inputEnd - inPos >= blockCount * 16 else {
                    throw ImageReaderError.invalid
                }
                outPos.update(from: inPos, count: blockCount * 16)
                inPos += blockCount * 16
                outPos += blockCount * 16
            default:
                // 0xF0 = no-op?
                break
            }
        }
    }

    private mutating func decode2(blockCount: Int, values: UnsafePointer<UInt8>) {
        for _ in 0..<blockCount * 2 {
            let bits = inPos.pointee
            inPos += 1
            for i in 0..<8 {
                let index = (bits >> (7 - i)) & 0x01
                outPos[i] = values[Int(index)]
            }
            outPos += 8
        }
    }

    private mutating func decode4(blockCount: Int, values: UnsafePointer<UInt8>) {
        for _ in 0..<blockCount * 4 {
            let bits = inPos.pointee
            inPos += 1
            for i in 0..<4 {
                let index = (bits >> (6 - i*2)) & 0x03
                outPos[i] = values[Int(index)]
            }
            outPos += 4
        }
    }

    private mutating func decode8(blockCount: Int, values: UnsafePointer<UInt8>) {
        for _ in 0..<blockCount {
            // Read 16 bits for each of the first three rows
            // The upper 12 bits are used in that row while the lower 4 are kept for the last row
            var finalBits: UInt16 = 0
            for row in 0..<3 {
                let bits = UInt16(inPos[0]) << 8 | UInt16(inPos[1])
                inPos += 2
                finalBits |= (bits & 0x0F) << (12 - row*4)
                for i in 0..<4 {
                    let index = (bits >> (13 - i*3)) & 0x07
                    outPos[i] = values[Int(index)]
                }
                outPos += 4
            }
            for i in 0..<4 {
                let index = (finalBits >> (13 - i*3)) & 0x07
                outPos[i] = values[Int(index)]
            }
            outPos += 4
        }
    }
}
