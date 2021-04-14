import Cocoa
import RFSupport

enum RleError: Error {
    case invalid
    case unsupported
}

typealias RleOp = UInt32
extension RleOp {
    enum code: UInt32 {
        case frameEnd   = 0x00000000
        case lineStart  = 0x01000000
        case pixels     = 0x02000000
        case skip       = 0x03000000
        case colorRun   = 0x04000000
    }
    var count: Int { Int(self & 0x00FFFFFF) / 2 }
    var code: RleOp.code? { RleOp.code(rawValue: self & 0xFF000000) }
    init(_ code: RleOp.code, count: Int) {
        self = code.rawValue | UInt32(count*2)
    }
    init(_ code: RleOp.code, bytes: Int = 0) {
        self = code.rawValue | UInt32(bytes)
    }
}

class Rle {
    private var reader: BinaryDataReader!
    let frameWidth: Int
    let frameHeight: Int
    let frameCount: Int
    private var writer: BinaryDataWriter!
    private var source: NSImageRep!
    private var currentFrame = 0
    
    var data: Data {
        writer?.data ?? reader.data
    }
    
    init(_ data: Data) throws {
        reader = BinaryDataReader(data)
        frameWidth = Int(try reader.read() as UInt16)
        frameHeight = Int(try reader.read() as UInt16)
        let depth = try reader.read() as UInt16
        guard depth == 16 else {
            throw RleError.unsupported
        }
        try reader.advance(2) // Palette is ignored for 16-bit
        frameCount = Int(try reader.read() as UInt16)
        try reader.advance(6)
    }
    
    init(image: NSImage, gridX: Int, gridY: Int) {
        source = image.representations[0]
        frameWidth = source.pixelsWide / gridX
        frameHeight = source.pixelsHigh / gridY
        frameCount = gridX * gridY
        
        writer = BinaryDataWriter(capacity: 16)
        writer.write(UInt16(frameWidth))
        writer.write(UInt16(frameHeight))
        writer.write(UInt16(16))
        writer.advance(2)
        writer.write(UInt16(frameCount))
        writer.advance(6)
    }
    
    func readFrame() throws -> NSBitmapImageRep {
        let frame = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: frameWidth,
                                     pixelsHigh: frameHeight,
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: frameWidth*4,
                                     bitsPerPixel: 0)!
        try self.readFrame(to: frame.bitmapData!, lineAdvance: frameWidth)
        return frame
    }
    
    func readSheet() throws -> NSBitmapImageRep {
        if reader == nil {
            reader = BinaryDataReader(self.data)
        }
        try reader.setPosition(16)
        var gridX = 6
        if frameCount <= gridX {
            gridX = frameCount
        } else {
            while frameCount % gridX != 0 {
                gridX += 1
            }
        }
        let gridY = frameCount / gridX
        let sheet = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: frameWidth * gridX,
                                     pixelsHigh: frameHeight * gridY,
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: frameWidth * gridX * 4,
                                     bitsPerPixel: 0)!
        let framePointer = sheet.bitmapData!
        for y in 0..<gridY {
            for x in 0..<gridX {
                let advance = (y*frameHeight*sheet.pixelsWide + x*frameWidth) * 4
                try self.readFrame(to: framePointer.advanced(by: advance), lineAdvance: sheet.pixelsWide)
            }
        }
        return sheet
    }
    
    private func readFrame(to framePointer: UnsafeMutablePointer<UInt8>, lineAdvance: Int) throws {
        var y = 0
        var x = 0
        var framePointer = framePointer
        while true {
            let op = try reader.read() as RleOp
            let count = op.count
            switch op.code {
            case .lineStart:
                guard y < frameHeight else {
                    throw RleError.invalid
                }
                if y != 0 {
                    framePointer = framePointer.advanced(by: (lineAdvance-x)*4)
                }
                x = 0
                y += 1
            case .skip:
                x += count
                guard x <= frameWidth else {
                    throw RleError.invalid
                }
                framePointer = framePointer.advanced(by: count*4)
            case .pixels:
                x += count
                guard x <= frameWidth else {
                    throw RleError.invalid
                }
                for pixel in try reader.readRaw(count: count) as [UInt16] {
                    self.write(UInt16(bigEndian: pixel), to: &framePointer)
                }
                if count % 2 != 0 {
                    try reader.advance(2)
                }
            case .colorRun:
                x += count
                guard x <= frameWidth else {
                    throw RleError.invalid
                }
                let pixel = try reader.read() as UInt16
                for _ in 0..<count {
                    self.write(pixel, to: &framePointer)
                }
                try reader.advance(2)
            case .frameEnd:
                guard y == frameHeight else {
                    throw RleError.invalid
                }
                return
            default:
                throw RleError.invalid
            }
        }
    }
    
    func writeFrame() -> NSBitmapImageRep {
        let gridX = source.pixelsWide / frameWidth
        let originX = currentFrame % gridX * frameWidth
        let originY = currentFrame / gridX * frameHeight
        currentFrame += 1
        let frame = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: frameWidth,
                                     pixelsHigh: frameHeight,
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: frameWidth*4,
                                     bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: frame)
        source.draw(in: NSRect(x: 0, y: 0, width: frameWidth, height: frameHeight),
                    from: NSRect(x: originX, y: source.pixelsHigh-originY-frameHeight, width: frameWidth, height: frameHeight),
                    operation: .copy,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil)
        
        var framePointer = frame.bitmapData!
        for _ in 0..<frameHeight {
            writer.write(RleOp(.lineStart))
            let linePos = writer.position
            var transparent = 0
            var pixels: [UInt16] = []
            for _ in 0..<frameWidth {
                if framePointer[3] == 0 {
                    framePointer = framePointer.advanced(by: 4)
                    transparent += 1
                } else {
                    if transparent != 0 {
                        // Starting pixel data after transparency, write the skip
                        if !pixels.isEmpty {
                            // We have previous unwritten pixel data, write this first
                            self.write(pixels: pixels)
                            pixels.removeAll()
                        }
                        writer.write(RleOp(.skip, count: transparent))
                        transparent = 0
                    }
                    var pixel: UInt16 = 0
                    for i in 0...2 {
                        pixel |= UInt16(framePointer[i] & 0xF8) << (7 - i*5)
                    }
                    self.write(pixel, to: &framePointer)
                    pixels.append(pixel.bigEndian)
                }
            }
            if !pixels.isEmpty {
                self.write(pixels: pixels)
                // Rewrite the line length
                writer.write(RleOp(.lineStart, bytes: writer.position-linePos), at: linePos-4)
            }
        }
        writer.write(RleOp(.frameEnd))
        return frame
    }
    
    private func write(_ pixel: UInt16, to framePointer: inout UnsafeMutablePointer<UInt8>) {
        // Extending 5-bits to 8-bits by adding zeros gives a very close result but is not technically correct.
        // For an accurate result we need to actually calculate the fraction that the 5 bits represent out of 8 bits.
        // Note division/multiplication is used here instead of bitshifts as it is much faster in unoptimised debug builds.
        framePointer[0] = UInt8(((pixel / 0x400) & 0x1F) * 0xFF / 0x1F)
        framePointer[1] = UInt8(((pixel /  0x20) & 0x1F) * 0xFF / 0x1F)
        framePointer[2] = UInt8(((pixel /     1) & 0x1F) * 0xFF / 0x1F)
        framePointer[3] = 0xFF
        framePointer = framePointer.advanced(by: 4)
    }
    
    private func write(pixels: [UInt16]) {
        writer.write(RleOp(.pixels, count: pixels.count))
        writer.writeRaw(pixels)
        if pixels.count % 2 != 0 {
            writer.advance(2)
        }
    }
}
