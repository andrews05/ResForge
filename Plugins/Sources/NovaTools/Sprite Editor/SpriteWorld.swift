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
                let pixelData = try reader.readData(length: byteCount)
                switch depth {
                case 8:
                    for pixel in pixelData {
                        ColorTable.system8[Int(pixel)].draw(to: &framePointer)
                    }
                case 16:
                    // Work directly with the bytes to skip bounds checks
                    pixelData.withUnsafeBytes { bytes in
                        for i in 0..<(bytes.count/2) {
                            RGBColor(hi: bytes[i * 2], lo: bytes[i * 2 + 1]).draw(to: &framePointer)
                        }
                    }
                default:
                    // Copy the bytes, converting XRGB to RGBA
                    pixelData.dropFirst().copyBytes(to: framePointer, count: byteCount - 1)
                    for _ in 0..<(byteCount/4) {
                        framePointer[3] = 0xFF
                        framePointer += 4
                    }
                }
                if byteCount % 4 != 0 {
                    try reader.advance(4 - (byteCount % 4))
                }
            case let .colorRun(byteCount):
                x += byteCount / pixelSize
                guard x <= frameWidth else {
                    throw SpriteError.invalid
                }
                let pixelData = try reader.readData(length: 4)
                switch depth {
                case 8:
                    let color = ColorTable.system8[Int(pixelData.first!)]
                    for _ in 0..<byteCount {
                        color.draw(to: &framePointer)
                    }
                case 16:
                    let color = RGBColor(hi: pixelData[pixelData.startIndex], lo: pixelData[pixelData.startIndex + 1])
                    for _ in 0..<(byteCount/2) {
                        color.draw(to: &framePointer)
                    }
                default:
                    let pixel = pixelData.dropFirst()
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

        frame.bitmapData!.withMemoryRebound(to: RGBColor.self, capacity: frameWidth * frameHeight) { pixels in
            var pixels = pixels
            var lineCount = 0
            var linePos = 0
            var pixelData: [UInt16] = []
            for _ in 0..<frameHeight {
                lineCount += 1
                var transparent = 0
                for _ in 0..<frameWidth {
                    if pixels.pointee.alpha == 0 {
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
                            if !pixelData.isEmpty {
                                // We have previous unwritten pixel data, write this first
                                self.write(bigEndianPixels: &pixelData)
                            }
                            writer.write(RleOp.skip(transparent * 2))
                            transparent = 0
                        }
                        pixels.pointee.reduceTo555()
                        pixelData.append(pixels.pointee.rgb555().bigEndian)
                    }
                    pixels += 1
                }
                if !pixelData.isEmpty {
                    self.write(bigEndianPixels: &pixelData)
                    // Rewrite the line length
                    writer.write(RleOp.lineStart(writer.bytesWritten-linePos).rawValue, at: linePos-4)
                }
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
