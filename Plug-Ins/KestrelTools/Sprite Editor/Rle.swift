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
    let frameWidth: Int
    let frameHeight: Int
    let frameCount: Int
    private var reader: BinaryDataReader!
    private var writer: BinaryDataWriter!
    
    var data: Data {
        writer?.data ?? reader.data
    }
    
    // Init for reading
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
    
    // Init for writing
    init(width: Int, height: Int, count: Int) {
        frameWidth = width
        frameHeight = height
        frameCount = count
        
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
                // The intention of this token is simply to repeat a single colour. But since the format is
                // 4-byte aligned, it's technically possible to repeat two different 16-bit colour values.
                // On big-endian machines this would presumably repeat them in order (untested), but on x86
                // versions of EV Nova they appear to be swapped. Here we reproduce the same behaviour.
                let pixel2 = try reader.read() as UInt16
                let pixel1 = try reader.read() as UInt16
                for _ in 0..<count/2 {
                    self.write(pixel1, to: &framePointer)
                    self.write(pixel2, to: &framePointer)
                }
                if count % 2 == 1 {
                    self.write(pixel1, to: &framePointer)
                }
            case .frameEnd:
                return
            default:
                throw RleError.invalid
            }
        }
    }
    
    func writeSheet(_ image: NSImage, dither: Bool = false) -> [NSBitmapImageRep] {
        let rep = image.representations[0]
        // Reset the resolution
        rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        var frames: [NSBitmapImageRep] = []
        for i in 0..<frameCount {
            let gridX = rep.pixelsWide / frameWidth
            let originX = i % gridX * frameWidth
            let originY = i / gridX * frameHeight
            let frame = self.newFrame()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: frame)
            rep.draw(in: NSRect(x: 0, y: 0, width: frameWidth, height: frameHeight),
                     from: NSRect(x: originX, y: rep.pixelsHigh-originY-frameHeight, width: frameWidth, height: frameHeight),
                     operation: .copy,
                     fraction: 1,
                     respectFlipped: true,
                     hints: nil)
            self.writeFrame(frame, dither: dither)
            frames.append(frame)
        }
        return frames
    }
    
    func writeFrames(_ images: [NSImage], dither: Bool = false) -> [NSBitmapImageRep] {
        var frames: [NSBitmapImageRep] = []
        for image in images {
            let rep = image.representations[0]
            // Reset the resolution
            rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            let frame = self.newFrame()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: frame)
            rep.draw()
            self.writeFrame(frame, dither: dither)
            frames.append(frame)
        }
        return frames
    }
    
    private func newFrame() -> NSBitmapImageRep {
        return NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: frameWidth,
                                pixelsHigh: frameHeight,
                                bitsPerSample: 8,
                                samplesPerPixel: 4,
                                hasAlpha: true,
                                isPlanar: false,
                                colorSpaceName: .deviceRGB,
                                bytesPerRow: frameWidth*4,
                                bitsPerPixel: 32)!
    }
    
    private func writeFrame(_ frame: NSBitmapImageRep, dither: Bool = false) {
        if dither {
            self.dither(frame)
        }
        
        var framePointer = frame.bitmapData!
        var lineCount = 0
        var linePos = 0
        for _ in 0..<frameHeight {
            lineCount += 1
            var transparent = 0
            var pixels: [UInt16] = []
            for _ in 0..<frameWidth {
                if framePointer[3] == 0 {
                    framePointer = framePointer.advanced(by: 4)
                    transparent += 1
                } else {
                    if lineCount != 0 {
                        // First pixel data for this line, write the line start
                        // Doing this only on demand allows us to omit trailing blank lines in the frame
                        for _ in 0..<lineCount {
                            writer.write(RleOp(.lineStart))
                        }
                        lineCount = 0
                        linePos = writer.position
                    }
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
                        let value = UInt16(framePointer[i] & 0xF8)
                        pixel |= value << (7 - i*5)
                        framePointer[i] = UInt8(value * 0xFF / 0xF8)
                    }
                    framePointer[3] = 0xFF
                    framePointer = framePointer.advanced(by: 4)
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
    }
    
    private func dither(_ frame: NSBitmapImageRep) {
        // QuickDraw dithering algorithm.
        // Half the error is diffused right on even rows, left on odd rows. The remainder is diffused down.
        let rowBytes = frame.bytesPerRow // This is a computed property, only access it once.
        let framePointer = frame.bitmapData!
        for y in 0..<frameHeight {
            let even = y % 2 == 0
            let row = even ? stride(from: 0, through: frameWidth-1, by: 1) : stride(from: frameWidth-1, through: 0, by: -1)
            for x in row {
                let p = y * rowBytes + x * 4
                for i in p...p+2 {
                    // To perfectly replicate QuickDraw we would simply take the error as the lower 3 bits of the value.
                    // This is not entirely accurate though and has the side-effect that repeat dithers will degrade the image.
                    // Instead we clip the lower 3 bits, restore it to 8-bits the same way we would when decoding (see `write` function), then take the difference.
                    let current = Int(framePointer[i])
                    let new = (current & 0xF8) * 0xFF / 0xF8
                    let error = current - new
                    if error != 0 {
                        if even && x+1 < frameWidth {
                            framePointer[i+4] = UInt8(clamping: Int(framePointer[i+4]) + error / 2)
                        } else if !even && x > 0 {
                            framePointer[i-4] = UInt8(clamping: Int(framePointer[i-4]) + error / 2)
                        }
                        if y+1 < frameHeight {
                            framePointer[i+rowBytes] = UInt8(clamping: Int(framePointer[i+rowBytes]) + (error+1) / 2)
                        }
                    }
                }
            }
        }
    }
    
    private func write(_ pixel: UInt16, to framePointer: inout UnsafeMutablePointer<UInt8>) {
        // Restoring 5-bits to 8-bits by bitshifting gives a very close result but is not entirely accurate.
        // The correct method is to calculate the fraction that the 5 bits represent out of 8 bits.
        // Note: division is used here instead of bitshifts as it is much faster in unoptimised debug builds.
        framePointer[0] = UInt8(((pixel / 0x400) & 0x1F) * 0xFF / 0x1F)
        framePointer[1] = UInt8(((pixel /  0x20) & 0x1F) * 0xFF / 0x1F)
        framePointer[2] = UInt8(((pixel        ) & 0x1F) * 0xFF / 0x1F)
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
