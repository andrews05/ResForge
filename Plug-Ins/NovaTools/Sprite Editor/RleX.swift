import Cocoa
import RFSupport

// RleX sprite, as seen in Cosmic Frontier
class RleX: SpriteWorld {
    override class var depth: Int { 32 }
    
    override func readSheet() throws -> NSBitmapImageRep {
        if reader == nil {
            reader = BinaryDataReader(self.data)
        }
        try reader.setPosition(16)
        let grid = self.sheetGrid()
        let sheet = self.newFrame(frameWidth * grid.x, frameHeight * grid.y)
        // RleX doesn't have line markers like RleD, which makes it harder to decode directly into a sheet.
        // Instead we'll just decode each frame and redraw them onto the sheet.
        // This naturally has a higher overhead but doesn't have a big impact on the overall export speed.
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: sheet)
        for y in 0..<grid.y {
            for x in 0..<grid.x {
                let frame = try self.readFrame()
                frame.draw(at: NSPoint(x: x * frameWidth, y: sheet.pixelsHigh - ((y+1) * frameHeight)))
            }
        }
        return sheet
    }
    
    override func readFrame(to framePointer: UnsafeMutablePointer<UInt8>, lineAdvance: Int) throws {
        for i in 0..<4 {
            // Decode each channel directly into the frame
            // Work with Pointers rather than Data for best performance
            let packLength = Int(try reader.read() as UInt32)
            try reader.readData(length: packLength).withUnsafeBytes {
                try self.decodePackBitsX($0.bindMemory(to: UInt8.self), to: framePointer+i)
            }
        }
    }
    
    private func decodePackBitsX(_ input: UnsafeBufferPointer<UInt8>, to output: UnsafeMutablePointer<UInt8>) throws {
        var pack = input.baseAddress!
        var frame = output
        let packEnd = pack + input.count
        let frameEnd = frame + frameWidth * frameHeight * 4
        while pack < packEnd {
            var run = Int(pack[0])
            pack += 1
            if run >= 0x80 {
                // Repeat single byte
                run ^= 0x80
                if run >= 0x70 {
                    // 2 byte count
                    guard pack < packEnd else {
                        throw SpriteError.invalid
                    }
                    // Combine 4 low bits with next byte
                    run = (run & 0x0F) << 8 | Int(pack[0])
                    pack += 1
                }
                let runEnd = frame + (run+1) * 4
                guard pack < packEnd && runEnd <= frameEnd else {
                    throw SpriteError.invalid
                }
                if pack[0] != 0 {
                    while frame < runEnd {
                        frame[0] = pack[0]
                        frame += 4
                    }
                } else {
                    frame = runEnd
                }
                pack += 1
            } else {
                // Copy bytes
                let runEnd = frame + (run+1) * 4
                guard pack+run < packEnd && runEnd <= frameEnd else {
                    throw SpriteError.invalid
                }
                while frame < runEnd {
                    frame[0] = pack[0]
                    frame += 4
                    pack += 1
                }
            }
        }
    }
    
    override func writeFrame(_ frame: NSBitmapImageRep, dither: Bool = false) {
        let framePointer = frame.bitmapData!
        // For best performance we'll use a fixed size output buffer, rather than e.g. incrementally appending to Data
        // In case of incompressible data we need to allocate the whole frame size plus a little extra
        let frameSize = frameWidth * frameHeight
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: frameSize + frameSize/128 + 1)
        for i in 0..<4 {
            // Encode each channel separately
            let packLength = self.encodePackBitsX(framePointer+i, to: buffer)
            writer.write(UInt32(packLength))
            writer.data.append(buffer, count: packLength)
        }
        buffer.deallocate()
    }
    
    // PackBits variant with extended runs
    private func encodePackBitsX(_ input: UnsafePointer<UInt8>, to output: UnsafeMutablePointer<UInt8>) -> Int {
        var frame = input
        var pack = output
        var frameEnd = frame + (frameWidth*frameHeight - 1) * 4
        // Trim trailing zeros
        while frameEnd >= frame && frameEnd[0] == 0 {
            frameEnd -= 4
        }
        while frame <= frameEnd {
            var run = 1
            let val = frame[0]
            frame += 4
            // Repeated run, up to 4096
            while run < 0x1000 && frame <= frameEnd && frame[0] == val {
                run += 1
                frame += 4
            }
            
            if run > 1 {
                run -= 1
                if run >= 0x70 {
                    // 2 byte run. 4 high bits are on, remaining 12 bits hold the count.
                    pack[0] = 0xF0 | UInt8(run >> 8)
                    pack[1] = UInt8(run & 0xFF)
                    pack[2] = val
                    pack += 3
                } else {
                    // Single byte run. High bit is on, remaining 7 bits hold the count.
                    pack[0] = UInt8(0x80 | run)
                    pack[1] = val
                    pack += 2
                }
                continue
            }
            
            // Literal run, up to 128
            // We want to avoid breaking a literal to make a run of 2, which would generally be less efficient
            pack[run] = val
            while run < 0x80 && (frame == frameEnd ||
                                (frame < frameEnd && frame[0] != frame[4]) ||
                                (frame < frameEnd-4 && frame[0] != frame[8])) {
                run += 1
                pack[run] = frame[0]
                frame += 4
            }
            
            pack[0] = UInt8(run - 1)
            pack += run + 1
        }
        return pack - output
    }
}
