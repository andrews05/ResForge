import RKSupport

enum RleError: Error {
    case invalid
    case unsupported
}

typealias RleOp = UInt32
extension RleOp {
    enum code: UInt32 {
        case frameEnd       = 0x00000000
        case lineStart      = 0x01000000
        case pixels         = 0x02000000
        case transparentRun = 0x03000000
        case colourRun      = 0x04000000
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
    private var source: NSBitmapImageRep!
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
        // Create a new bitmap representation of the image in the layout that we need
        let rep = image.representations[0]
        source = NSBitmapImageRep(bitmapDataPlanes: nil,
                                  pixelsWide: rep.pixelsWide,
                                  pixelsHigh: rep.pixelsHigh,
                                  bitsPerSample: 8,
                                  samplesPerPixel: 4,
                                  hasAlpha: true,
                                  isPlanar: false,
                                  colorSpaceName: .deviceRGB,
                                  bytesPerRow: rep.pixelsWide*4,
                                  bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: source)
        rep.draw()
        NSGraphicsContext.restoreGraphicsState()
    
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
            case .transparentRun:
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
            case .colourRun:
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
        var framePointer = frame.bitmapData!
        let sourcePointer = source.bitmapData!
        for y in originY..<(originY+frameHeight) {
            writer.write(RleOp(.lineStart))
            let linePos = writer.position
            var transparent = 0
            var pixels: [UInt16] = []
            for x in originX..<(originX+frameWidth) {
                let p = (y*source.pixelsWide+x) * 4
                if sourcePointer[p+3] == 0 {
                    framePointer = framePointer.advanced(by: 4)
                    transparent += 1
                } else {
                    if transparent != 0 {
                        // Starting pixel data after transparency, write the transparent run
                        if !pixels.isEmpty {
                            // We have previous unwritten pixel data, write this first
                            self.write(pixels: pixels)
                            pixels.removeAll()
                        }
                        writer.write(RleOp(.transparentRun, count: transparent))
                        transparent = 0
                    }
                    let pixel =
                        UInt16(sourcePointer[p] & 0xF8) * 0x80 |
                        UInt16(sourcePointer[p+1] & 0xF8) * 0x04 |
                        UInt16(sourcePointer[p+2] & 0xF8) / 0x08
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
        // Division/multiplication is used here instead of bitshifts as it is much faster in unoptimised debug builds
        framePointer[0] = UInt8((pixel & 0x7C00) / 0x80)
        framePointer[1] = UInt8((pixel & 0x03E0) / 0x04)
        framePointer[2] = UInt8((pixel & 0x001F) * 0x08)
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
