import RFSupport

// `pxm#` resource used in old Mac OS X theme files
// No documentation found

struct Pxm {
    static let sharedMask: UInt16 = 0x1
    var imageRep: NSBitmapImageRep

    init(_ reader: BinaryDataReader) throws {
        let version = try reader.read() as UInt16
        let flags = try reader.read() as UInt16
        try reader.advance(4)
        let height = Int(try reader.read() as UInt16)
        let width = Int(try reader.read() as UInt16)
        try reader.advance(10)
        let count = Int(try reader.read() as UInt16)
        guard version == 3,
              width > 0, height > 0, count > 0
        else {
            throw ImageReaderError.invalidData
        }
        
        // 1-bit click mask, round row bytes up to multiple of 2
        let maskRowBytes = (width + 15) / 16 * 2
        var maskSize = maskRowBytes * height
        if (flags & Self.sharedMask) == 0 {
            maskSize *= count
        }
        try reader.advance(maskSize)
        let bitmapSize = width * height * count * 4
        let rgbaData = [UInt8](try reader.readData(length: bitmapSize))

        imageRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: width,
                                    pixelsHigh: height * count,
                                    bitsPerSample: 8,
                                    samplesPerPixel: 4,
                                    hasAlpha: true,
                                    isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bytesPerRow: width * 4,
                                    bitsPerPixel: 32)!
        rgbaData.withUnsafeBufferPointer {
            imageRep.bitmapData!.update(from: $0.baseAddress!, count: bitmapSize)
        }
    }

    static func rep(_ data: Data, format: inout UInt32) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data, bigEndian: false)
        guard let pxm = try? Self(reader) else {
            return nil
        }
        return pxm.imageRep
    }
}
