import Cocoa
import RFSupport

// RleX sprite, as seen in Cosmic Frontier
class RleX: SpriteWorld {
    override class var depth: Int { 32 }
    
    override func readFrame(to framePointer: UnsafeMutablePointer<UInt8>, lineAdvance: Int) throws {
        var luma: UInt8 = 0
        var redDiff: UInt8 = 128
        var blueDiff: UInt8 = 128
        var alpha: UInt8 = 255
        var framePointer = UnsafeMutableRawPointer(framePointer).assumingMemoryBound(to: UInt32.self)
        var pos = 0
        while true {
            guard let op = RleXOp(rawValue: try reader.read()) else {
                throw SpriteError.invalid
            }
            var advance = 0
            switch op {
            case .luma:
                luma = try reader.read()
            case .redDiff:
                redDiff = try reader.read()
            case .blueDiff:
                blueDiff = try reader.read()
            case .alpha:
                alpha = try reader.read()
            case .advance:
                advance = Int(try reader.read() as UInt32)
            case let .shortAdvance(count):
                advance = count
            case .frameEnd:
                return
            }
            
            if advance != 0 {
                if pos + advance > frameWidth * frameHeight {
                    throw SpriteError.invalid
                }
                let rgb = yuv2rgb(y: luma, cb: blueDiff, cr: redDiff)
                let val = (UInt32(rgb.r) << 24 | UInt32(rgb.g) << 16 | UInt32(rgb.b) << 8 | UInt32(alpha)).bigEndian
                // When reading as a sheet we need to adhere to the lineAdvance when completing each line,
                // rather than just assigning the full count in one go
                while advance > 0 {
                    var count = min(advance, frameWidth - pos % frameWidth)
                    framePointer.assign(repeating: val, count: count)
                    pos += count
                    advance -= count
                    if pos % frameWidth == 0 {
                        count += lineAdvance - frameWidth
                    }
                    framePointer = framePointer.advanced(by: count)
                }
            }
        }
    }
    
    override func writeFrame(_ frame: NSBitmapImageRep, dither: Bool = false) {
        var framePointer = frame.bitmapData!
        var yuv: (y: UInt8, cb: UInt8, cr: UInt8) = (0, 128, 128)
        var alpha: UInt8 = 255
        var count = 0
        for _ in 0..<(frameWidth * frameHeight) {
            let nextAlpha = framePointer[3]
            
            // Don't bother reading colour value when alpha is zero
            if nextAlpha > 0 {
                let nextYuv = rgb2yuv(r: framePointer[0], g: framePointer[1], b: framePointer[2])
                if nextYuv != yuv {
                    self.writeAdvance(count)
                    count = 0
                    if nextYuv.y != yuv.y {
                        writer.write(RleXOp.luma.rawValue)
                        writer.write(nextYuv.y)
                    }
                    if nextYuv.cb != yuv.cb {
                        writer.write(RleXOp.blueDiff.rawValue)
                        writer.write(nextYuv.cb)
                    }
                    if nextYuv.cr != yuv.cr {
                        writer.write(RleXOp.redDiff.rawValue)
                        writer.write(nextYuv.cr)
                    }
                    yuv = nextYuv
                }
            }
            
            if nextAlpha != alpha {
                self.writeAdvance(count)
                count = 0
                writer.write(RleXOp.alpha.rawValue)
                writer.write(nextAlpha)
                alpha = nextAlpha
            }
            
            framePointer = framePointer.advanced(by: 4)
            count += 1
        }
        
        self.writeAdvance(count)
        writer.write(RleXOp.frameEnd.rawValue)
    }
    
    private func writeAdvance(_ count: Int) {
        if count > 127 {
            writer.write(RleXOp.advance.rawValue)
            writer.write(UInt32(count))
        } else if count > 0 {
            writer.write(RleXOp.shortAdvance(count).rawValue)
        }
    }
    
    private func yuv2rgb(y: UInt8, cb: UInt8, cr: UInt8) -> (r: UInt8, g: UInt8, b: UInt8) {
        let y = Double(y)
        let cb = Double(cb) - 128
        let cr = Double(cr) - 128
        let r = UInt8(clamping: Int(y + 1.402000 * cr))
        let g = UInt8(clamping: Int(y - 0.344136 * cb - 0.714136 * cr))
        let b = UInt8(clamping: Int(y + 1.772000 * cb))
        return (r, g, b)
    }
    
    private func rgb2yuv(r: UInt8, g: UInt8, b: UInt8) -> (y: UInt8, cb: UInt8, cr: UInt8) {
        let r = Double(r)
        let g = Double(g)
        let b = Double(b)
        let y = UInt8(clamping: Int(0.299000 * r + 0.587000 * g + 0.114000 * b))
        let cb = UInt8(clamping: Int(128 - 0.168736 * r - 0.331264 * g + 0.500000 * b))
        let cr = UInt8(clamping: Int(128 + 0.500000 * r - 0.418688 * g - 0.081312 * b))
        return (y, cb, cr)
    }
}

enum RleXOp: RawRepresentable {
    case frameEnd
    case luma
    case redDiff
    case blueDiff
    case alpha
    case advance
    case shortAdvance(Int)
    
    init?(rawValue: UInt8) {
        switch rawValue {
        case 0:
            self = .frameEnd
        case 1:
            self = .luma
        case 2:
            self = .redDiff
        case 3:
            self = .blueDiff
        case 4:
            self = .alpha
        case 5:
            self = .advance
        default:
            if rawValue & 0x80 != 0 {
                self = .shortAdvance(Int(rawValue & ~0x80))
            } else {
                return nil
            }
        }
    }
    
    var rawValue: UInt8 {
        switch self {
        case .frameEnd:
            return 0
        case .luma:
            return 1
        case .redDiff:
            return 2
        case .blueDiff:
            return 3
        case .alpha:
            return 4
        case .advance:
            return 5
        case let .shortAdvance(count):
            return 0x80 | UInt8(count)
        }
    }
}
