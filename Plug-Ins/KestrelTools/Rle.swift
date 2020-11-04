import RKSupport

enum RleError: Error {
    case invalid
    case unsupported
}

enum RleOpcode: Int {
    case frameEnd = 0, lineStart, pixels, transparentRun, colourRun
}

class Rle {
    private let reader: BinaryDataReader
    let frameWidth: Int
    let frameHeight: Int
    let frameCount: Int
    
    init(_ data: Data) throws {
        reader = BinaryDataReader(data)
        frameWidth = Int(try reader.read() as UInt16)
        frameHeight = Int(try reader.read() as UInt16)
        let depth = try reader.read() as UInt16
        guard depth == 16 else {
            throw RleError.unsupported
        }
        //let palette = try reader.read() as UInt16
        try reader.advance(2)
        frameCount = Int(try reader.read() as UInt16)
        try reader.advance(6)
    }
    
    func readFrame() throws -> NSBitmapImageRep {
        var y = 0
        var x = 0
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
        while true {
            var bytes = Int(try reader.read() as UInt32)
            let opcode = RleOpcode(rawValue: bytes >> 24)
            bytes &= 0x00FFFFFF
            guard bytes % 2 == 0 else {
                throw RleError.invalid
            }
            let count = bytes / 2
            switch opcode {
            case .lineStart:
                guard y < frameHeight else {
                    throw RleError.invalid
                }
                if y != 0 {
                    framePointer = framePointer.advanced(by: (frameWidth-x)*4)
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
                if bytes % 4 != 0 {
                    try reader.advance(4 - bytes%4)
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
                return frame
            default:
                throw RleError.invalid
            }
        }
    }
    
    private func write(_ pixel: UInt16, to framePointer: inout UnsafeMutablePointer<UInt8>) {
        // Division/multiplication is used here instead of bitshifts as it is much faster in unoptimised debug builds
        framePointer.pointee = UInt8((pixel & 0x7C00) / 0x80)
        framePointer = framePointer.successor()
        framePointer.pointee = UInt8((pixel & 0x03E0) / 0x04)
        framePointer = framePointer.successor()
        framePointer.pointee = UInt8((pixel & 0x001F) * 0x08)
        framePointer = framePointer.successor()
        framePointer.pointee = 0xFF
        framePointer = framePointer.successor()
    }
}
