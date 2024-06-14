import AppKit

class Icons {
    static func rep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        if depth == 1 {
            return self.bwRep(data, width: width, height: height)
        }
        return self.colorRep(data, width: width, height: height, depth: depth)
    }

    static func multiRep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        guard data.count > 1 else {
            return nil
        }
        // This just stacks all the patterns vertically
        let count = Int(data[data.startIndex + 1])
        return Self.rep(data.dropFirst(2), width: width, height: height * count, depth: depth)
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
