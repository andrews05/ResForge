import AppKit
import RFSupport
import ImageEditor

// SpriteWorld RLE sprite, as seen in EV Nova
class SpriteWorld: Sprite {
    let frameWidth: Int
    let frameHeight: Int
    let depth: Int
    let frameCount: Int
    var reader: BinaryDataReader!
    var writer: BinaryDataWriter!

    var data: Data {
        writer?.data ?? reader.data
    }

    // Init for reading
    required init(_ data: Data) throws {
        reader = BinaryDataReader(data)
        frameWidth = Int(try reader.read() as UInt16)
        frameHeight = Int(try reader.read() as UInt16)
        guard frameWidth > 0, frameHeight > 0 else {
            throw SpriteError.invalid
        }
        depth = Int(try reader.read() as UInt16)
        guard depth == 8 || depth == 16 || depth == 32 else {
            throw SpriteError.unsupported
        }
        try reader.advance(2) // Custom clut not currently supported
        frameCount = Int(try reader.read() as UInt16)
        try reader.advance(6)
    }

    // Init for writing
    required init(width: Int, height: Int, count: Int) {
        frameWidth = width
        frameHeight = height
        frameCount = count
        depth = 16

        writer = BinaryDataWriter(capacity: 16)
        writer.write(UInt16(frameWidth))
        writer.write(UInt16(frameHeight))
        writer.write(UInt16(depth))
        writer.advance(2)
        writer.write(UInt16(frameCount))
        writer.advance(6)
    }

    func readFrame() throws -> NSBitmapImageRep {
        let frame = self.newFrame()
        try self.readFrame(to: frame.bitmapData!, lineAdvance: frameWidth)
        return frame
    }

    func readSheet() throws -> NSBitmapImageRep {
        if reader == nil {
            reader = BinaryDataReader(self.data)
        }
        try reader.setPosition(16)
        let grid = self.sheetGrid()
        let sheet = self.newFrame(frameWidth * grid.x, frameHeight * grid.y)
        let framePointer = sheet.bitmapData!
        for y in 0..<grid.y {
            for x in 0..<grid.x {
                let advance = (y*frameHeight*sheet.pixelsWide + x*frameWidth) * 4
                try self.readFrame(to: framePointer+advance, lineAdvance: sheet.pixelsWide)
            }
        }
        return sheet
    }

    func readFrame(to framePointer: UnsafeMutablePointer<UInt8>, lineAdvance: Int) throws {
        var y = 0
        var x = 0
        var framePointer = framePointer
        let pixelSize = depth / 8
        while true {
            let op = try reader.read() as RleOp
            switch op {
            case .lineStart:
                guard y < frameHeight else {
                    throw SpriteError.invalid
                }
                if y != 0 {
                    framePointer += (lineAdvance-x) * 4
                }
                x = 0
                y += 1
            case let .skip(byteCount):
                x += byteCount / pixelSize
                guard x <= frameWidth else {
                    throw SpriteError.invalid
                }
                framePointer += byteCount / pixelSize * 4
            case let .pixels(byteCount):
                x += byteCount / pixelSize
                guard x <= frameWidth, byteCount % pixelSize == 0 else {
                    throw SpriteError.invalid
                }
                let data = try reader.readData(length: byteCount)
                switch depth {
                case 8:
                    for pixel in data {
                        ColorTable.system8[Int(pixel)].draw(to: &framePointer)
                    }
                case 16:
                    // Work directly with the bytes - this is much faster than reading the pixels one at a time
                    data.withUnsafeBytes { bytes in
                        // Note: we can't use `withMemoryRebound` as the data may not be aligned
                        for pixel in bytes.bindMemory(to: UInt16.self) {
                            self.draw(UInt16(bigEndian: pixel), to: &framePointer)
                        }
                    }
                default:
                    // Copy the bytes, converting XRGB to RGBA
                    data.dropFirst().copyBytes(to: framePointer, count: byteCount - 1)
                    for i in stride(from: 3, to: byteCount, by: 4) {
                        framePointer[i] = 0xFF
                    }
                    framePointer += byteCount
                }
                if byteCount % 4 != 0 {
                    try reader.advance(4 - (byteCount % 4))
                }
            case let .colorRun(byteCount):
                x += byteCount / pixelSize
                guard x <= frameWidth else {
                    throw SpriteError.invalid
                }
                switch depth {
                case 8:
                    let idx = Int(try reader.read() as UInt8)
                    try reader.advance(3)
                    let color = ColorTable.system8[idx]
                    for _ in 0..<byteCount {
                        color.draw(to: &framePointer)
                    }
                case 16:
                    // The intention of this token is simply to repeat a single colour. But since the format is
                    // 4-byte aligned, it's technically possible to repeat two different 16-bit colour values.
                    // On big-endian machines this would presumably repeat them in order (untested), but on x86
                    // versions of EV Nova they appear to be swapped. Here we reproduce the x86 behaviour.
                    let pixels: [UInt16] = [try reader.read(), try reader.read()]
                    for i in 1...(byteCount/2) {
                        self.draw(pixels[i%2], to: &framePointer)
                    }
                default:
                    let pixel = try reader.readData(length: 4).dropFirst()
                    for _ in 0..<(byteCount/4) {
                        pixel.copyBytes(to: framePointer, count: 3)
                        framePointer[3] = 0xFF
                        framePointer += 4
                    }
                }
            case .frameEnd:
                return
            }
        }
    }

    private func draw(_ pixel: UInt16, to framePointer: inout UnsafeMutablePointer<UInt8>) {
        // Note: division is used here instead of bitshifts as it is much faster in unoptimised debug builds.
        let r = UInt8((pixel & 0x7C00) / 0x80)
        let g = UInt8((pixel & 0x03E0) / 0x04)
        let b = UInt8((pixel & 0x001F) * 0x08)
        // To accurately restore 5-bits to 8-bits (and match QuickDraw output), copy the upper 3 bits to the lower 3 bits.
        framePointer[0] = r | (r / 0x20)
        framePointer[1] = g | (g / 0x20)
        framePointer[2] = b | (b / 0x20)
        framePointer[3] = 0xFF
        framePointer += 4
    }
}

extension SpriteWorld: WriteableSprite {
    func writeSheet(_ rep: NSImageRep, dither: Bool = false) -> [NSBitmapImageRep] {
        // Reset the resolution
        rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        let gridX = rep.pixelsWide / frameWidth
        var frames: [NSBitmapImageRep] = []
        for i in 0..<frameCount {
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

    func writeFrames(_ reps: [NSImageRep], dither: Bool = false) -> [NSBitmapImageRep] {
        var frames: [NSBitmapImageRep] = []
        for rep in reps {
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

    func writeFrame(_ frame: NSBitmapImageRep, dither: Bool = false) {
        if dither {
            self.dither(frame)
        }

        var framePointer = frame.bitmapData!
        var lineCount = 0
        var linePos = 0
        var pixels: [UInt16] = []
        for _ in 0..<frameHeight {
            lineCount += 1
            var transparent = 0
            for _ in 0..<frameWidth {
                if framePointer[3] == 0 {
                    framePointer += 4
                    transparent += 1
                } else {
                    if lineCount != 0 {
                        // First pixel data for this line, write the line start
                        // Doing this only on demand allows us to omit trailing blank lines in the frame
                        for _ in 0..<lineCount {
                            writer.write(RleOp.lineStart(0))
                        }
                        lineCount = 0
                        linePos = writer.bytesWritten
                    }
                    if transparent != 0 {
                        // Starting pixel data after transparency, write the skip
                        if !pixels.isEmpty {
                            // We have previous unwritten pixel data, write this first
                            self.write(bigEndianPixels: &pixels)
                        }
                        writer.write(RleOp.skip(transparent * 2))
                        transparent = 0
                    }
                    let pixel = UInt16(framePointer[0] & 0xF8) * 0x80
                              + UInt16(framePointer[1] & 0xF8) * 0x04
                              + UInt16(framePointer[2] & 0xF8) / 0x08
                    self.draw(pixel, to: &framePointer)
                    pixels.append(pixel.bigEndian)
                }
            }
            if !pixels.isEmpty {
                self.write(bigEndianPixels: &pixels)
                // Rewrite the line length
                writer.write(RleOp.lineStart(writer.bytesWritten-linePos).rawValue, at: linePos-4)
            }
        }
        writer.write(RleOp.frameEnd)
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
                    // To fix this we subtract from that the upper 3 bits (see 5-bit restoration in `draw` function).
                    let error = Int(framePointer[i] & 0x7) - Int(framePointer[i] / 0x20)
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

    private func write(bigEndianPixels pixels: inout [UInt16]) {
        writer.write(RleOp.pixels(pixels.count * 2))
        if pixels.count % 2 != 0 {
            pixels.append(0)
        }
        // Append the bytes directly to the data - this is much faster than writing the pixels one at a time
        pixels.withUnsafeBufferPointer {
            writer.data.append($0)
        }
        pixels.removeAll(keepingCapacity: true)
    }
}

enum RleOp: RawRepresentable {
    case frameEnd
    case lineStart(Int)
    case pixels(Int)
    case skip(Int)
    case colorRun(Int)

    init?(rawValue: UInt32) {
        let byteCount = Int(rawValue & 0x00FFFFFF)
        switch rawValue >> 24 {
        case 0:
            self = .frameEnd
        case 1:
            self = .lineStart(byteCount)
        case 2:
            self = .pixels(byteCount)
        case 3:
            self = .skip(byteCount)
        case 4:
            self = .colorRun(byteCount)
        default:
            return nil
        }
    }

    var rawValue: UInt32 {
        switch self {
        case .frameEnd:
            return 0
        case let .lineStart(byteCount):
            return 1 << 24 | UInt32(byteCount)
        case let .pixels(byteCount):
            return 2 << 24 | UInt32(byteCount)
        case let .skip(byteCount):
            return 3 << 24 | UInt32(byteCount)
        case let .colorRun(byteCount):
            return 4 << 24 | UInt32(byteCount)
        }
    }
}
