import AppKit

class Icons {
    static func rep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        if depth == 1 {
            return self.bwRep(data, width: width, height: height)
        }
        return self.colorRep(data, width: width, height: height, depth: depth)
    }

    static func multiRep(_ data: Data, width: Int, height: Int, depth: Int, count: Int? = nil) -> NSBitmapImageRep? {
        guard data.count > 1 else {
            return nil
        }
        // This just stacks all the patterns vertically
        let actualCount = count ?? Int(data[data.startIndex + 1] | (data[data.startIndex] << 8))
        let longRep = Self.rep((count == nil) ? data.dropFirst(2) : data, width: width, height: height * actualCount, depth: depth)
        
        // Now split it up in vertical columns in a more efficient layout.
        let patternsPerColumn = Int(floor(sqrt(Double(actualCount))))
        let numColumns = Int(ceil(Double(actualCount) / Double(patternsPerColumn)))
        
        let srcSize = NSSize(width: width, height: height * actualCount)
        let dstSize = NSSize(width: width * numColumns, height: height * patternsPerColumn)
        let img = NSImage(size: dstSize,
                          flipped: false) { box in
            for colIndex in 0..<numColumns {
                let srcY = srcSize.height - Double((colIndex + 1) * (height * patternsPerColumn))
                let srcBox = NSRect(origin: NSPoint(x: 0, y: srcY), size: NSSize(width: width, height: height * patternsPerColumn))
                let dstBox = NSRect(origin: NSPoint(x: colIndex * width, y: 0), size: NSSize(width: width, height: height * patternsPerColumn))
                longRep?.draw(in: dstBox, from: srcBox, operation: .copy, fraction: 1.0, respectFlipped: false, hints: nil)
            }
            return true
        }
        
        if let tiffData = img.tiffRepresentation {
            return NSBitmapImageRep(data: tiffData)
        }
        return nil
    }

    private static func bwRep(_ data: Data, width: Int, height: Int) -> NSBitmapImageRep? {
        let bytesPerRow = width / 8
        let planeLength = bytesPerRow * height
        guard data.count >= planeLength else {
            return nil
        }

        // Assume mask if sufficient data
        let hasMask = data.count >= planeLength * 2
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 1,
                                   samplesPerPixel: hasMask ? 2 : 1,
                                   hasAlpha: hasMask,
                                   isPlanar: true,
                                   colorSpaceName: .deviceWhite,
                                   bytesPerRow: bytesPerRow,
                                   bitsPerPixel: 1)!
        let bitmap = rep.bitmapData!
        data.copyBytes(to: bitmap, count: rep.numberOfPlanes * planeLength)
        // Invert bitmap plane
        for i in 0..<planeLength {
            bitmap[i] ^= 0xFF
        }
        return rep
    }

    private static func colorRep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        guard depth == 4 || depth == 8,
              data.count == width * height * depth / 8
        else {
            return nil
        }

        let rep = ImageFormat.rgbaRep(width: width, height: height)
        var bitmap = rep.bitmapData!
        if depth == 4 {
            let palette = ColorTable.system4
            for byte in data {
                palette[Int(byte >> 4)].draw(to: &bitmap)
                palette[Int(byte & 0x0F)].draw(to: &bitmap)
            }
        } else if depth == 8 {
            let palette = ColorTable.system8
            for byte in data {
                palette[Int(byte)].draw(to: &bitmap)
            }
        }
        return rep
    }
}
