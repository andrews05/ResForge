import RFSupport

// https://vintageapple.org/inside_r/pdf/QuickTime_1993.pdf#509

struct QTImageDesc {
    static let minSize = 86
    var size: Int32
    var compressor: UInt32
    var version: UInt32
    var width: Int16
    var height: Int16
    var dataSize: Int32
    var depth: Int16
    var clutID: Int16

    var colorTable: [RGBColor]?
    /// Number of remaining bytes of the image description before the start of the data.
    var bytesUntilData: Int
}

extension QTImageDesc {
    /// The actual bit depth, accounting for grayscale depths over 32.
    var resolvedDepth: Int {
        Int(depth > 32 ? depth - 32 : depth)
    }

    init(_ reader: BinaryDataReader) throws {
        let start = reader.position
        size = try reader.read()
        compressor = try reader.read()
        try reader.advance(4 + 2 + 2) // reserved, reserved, dataRefIndex
        version = try reader.read()
        try reader.advance(4 + 4 + 4) // vendor, temporalQuality, spatialQuality
        width = try reader.read()
        height = try reader.read()
        try reader.advance(8) // hRes, vRes
        dataSize = try reader.read()
        try reader.advance(2 + 32) // frameCount, name
        depth = try reader.read()
        clutID = try reader.read()

        guard size >= Self.minSize,
              width > 0,
              height > 0,
              dataSize > 0,
              depth > 0
        else {
            throw ImageReaderError.invalidData
        }

        if clutID == 0 {
            colorTable = try ColorTable.read(reader)
        } else if clutID > 0 {
            colorTable = try ColorTable.get(id: clutID)
        }

        bytesUntilData = start + Int(size) - reader.position
    }

    func readImage(_ reader: BinaryDataReader) throws -> NSBitmapImageRep {
        switch compressor.fourCharString {
        case "qdrw":
            // QuickDraw Picture
            try reader.advance(bytesUntilData)
            return try Picture(reader).imageRep
        case "raw ":
            return try QTNone.rep(for: self, reader: reader)
        case "8BPS":
            return try QTPlanar.rep(for: self, reader: reader)
        default:
            // Attempt to let the system decode it. This should work for e.g. PNG, JPEG, GIF, TIFF.
            try reader.advance(bytesUntilData)
            let data = try reader.readData(length: Int(dataSize))
            guard let rep = NSBitmapImageRep(data: data) else {
                throw ImageReaderError.unsupported
            }
            if compressor.fourCharString == "png " {
                // Older QuickTime versions (<6.5) stored png data as non-standard RGBX
                // We need to disable the alpha, but first ensure the image has been decoded by accessing the bitmapData
                _ = rep.bitmapData
                rep.hasAlpha = false
            }
            return rep
        }
    }

    /// Construct a PixMap than can be used to blit pixel data.
    func blitter(rowBytes: Int) -> QDPixMap {
        return QDPixMap(bounds: QDRect(bottom: height, right: width),
                        pixelSize: Int16(resolvedDepth),
                        rowBytes: rowBytes)
    }
}
