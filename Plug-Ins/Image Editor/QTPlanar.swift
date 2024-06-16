import AppKit
import RFSupport

// https://wiki.multimedia.cx/index.php/8BPS

/// Decoder for the QuickTime "8BPS" (Adobe Photoshop) compressor.
struct QTPlanar {
    static func rep(for imageDesc: QTImageDesc, reader: BinaryDataReader) throws -> NSBitmapImageRep {
        let width = Int(imageDesc.width)
        let height = Int(imageDesc.height)
        let depth = imageDesc.resolvedDepth

        // Start by inferring the channel count from the depth
        var channelCount = max(depth / 8, 1)
        // Parse the remaining atoms to see if there's an explicit channel count
        var remaining = imageDesc.bytesUntilData
        while remaining >= 10 {
            let size = Int(try reader.read() as UInt32)
            let type = try reader.read() as UInt32
            if type.fourCharString == "chct" {
                channelCount = Int(try reader.read() as UInt16)
                remaining -= 10
                break
            }
            try reader.advance(size - 8)
            remaining -= size
        }
        try reader.advance(remaining)

        var data: Data
        if imageDesc.version == 0 {
            // Uncompressed
            data = try reader.readData(length: Int(imageDesc.dataSize))
        } else {
            // PackBits - all line counts are stored first
            var packLength = 0
            for _ in 0..<(height * channelCount) {
                packLength += Int(try reader.read() as UInt16)
            }
            let packed = try reader.readData(length: packLength)
            let outputSize = width * height * channelCount
            data = Data(repeating: 0, count: outputSize)
            try data.withUnsafeMutableBytes { output in
                try packed.withUnsafeBytes { input in
                    try PackBits<UInt8>.decode(input, to: output.baseAddress!, outputSize: outputSize)
                }
            }
        }

        switch depth {
        case 1, 8:
            // Determine row bytes based on width and depth
            let rowBytes = (width * depth + 7) / 8
            // Monochrome images don't specify a clut - fallback to system1
            let colorTable = imageDesc.colorTable ?? ColorTable.system1
            return try imageDesc.blitter(rowBytes: rowBytes).imageRep(pixelData: data, colorTable: colorTable)
        case 24, 32:
            // Construct a 3-channel planar image rep, ignoring any additional channels in the data
            let size = width * height * 3
            guard data.count >= size else {
                throw ImageReaderError.invalid
            }
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                       pixelsWide: width,
                                       pixelsHigh: height,
                                       bitsPerSample: 8,
                                       samplesPerPixel: 3,
                                       hasAlpha: false,
                                       isPlanar: true,
                                       colorSpaceName: .deviceRGB,
                                       bytesPerRow: width,
                                       bitsPerPixel: 0)!
            data.copyBytes(to: rep.bitmapData!, count: size)
            return rep
        default:
            // Depths 2, 4 and 16 are not known to be valid
            throw ImageReaderError.invalid
        }
    }
}
