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
                let rgb = yuv2rgb(luma: luma, blueDiff: blueDiff, redDiff: redDiff)
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
    
    private func yuv2rgb(luma: UInt8, blueDiff: UInt8, redDiff: UInt8) -> (r: UInt8, g: UInt8, b: UInt8) {
        let Y = Double(luma)
        let Cb = Double(blueDiff) - 128
        let Cr = Double(redDiff) - 128
        let r = UInt8(clamping: Int(Y + 1.402000 * Cr))
        let g = UInt8(clamping: Int(Y - 0.344136 * Cb - 0.714136 * Cr))
        let b = UInt8(clamping: Int(Y + 1.772000 * Cb))
        return (r, g, b)
    }
    
    override func writeFrame(_ frame: NSBitmapImageRep, dither: Bool = false) {
        // TODO
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
