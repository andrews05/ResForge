import AppKit
import RFSupport

// https://vintageapple.org/inside_r/pdf/QuickTime_1993.pdf#509

struct QTImageDesc {
    static let png = UInt32(fourCharString: "png ")
    static let jpeg = UInt32(fourCharString: "jpeg")
    static let gif = UInt32(fourCharString: "gif ")
    static let tiff = UInt32(fourCharString: "tiff")
    static let animation = UInt32(fourCharString: "rle ")
    static let none = UInt32(fourCharString: "raw ")
    static let planar = UInt32(fourCharString: "8BPS")
    static let quickDraw = UInt32(fourCharString: "qdrw")

    var size: UInt32 = 86
    var compressor: UInt32
    var version: UInt16 = 1
    var revisionLevel: UInt16 = 1
    var vendor: UInt32 = UInt32(fourCharString: "appl")
    var width: Int16
    var height: Int16
    var hRes: UInt32 = 0x00480000
    var vRes: UInt32 = 0x00480000
    var dataSize: UInt32
    var frameCount: Int16 = 1
    var name: String
    var depth: Int16
    var clutID: Int16 = -1

    var colorTable: [RGBColor]? = nil
    /// Number of remaining bytes of the image description before the start of the data.
    var bytesUntilData = 0
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
        revisionLevel = try reader.read()
        vendor = try reader.read()
        try reader.advance(4 + 4) // temporalQuality, spatialQuality
        width = try reader.read()
        height = try reader.read()
        hRes = try reader.read()
        vRes = try reader.read()
        dataSize = try reader.read()
        frameCount = try reader.read()
        name = try reader.readPString(fixedSize: 32)
        depth = try reader.read()
        clutID = try reader.read()

        if clutID == 0 {
            colorTable = try ColorTable.read(reader)
        } else if clutID > 0 {
            colorTable = try ColorTable.get(id: clutID)
        }

        bytesUntilData = start + Int(size) - reader.position

        guard bytesUntilData >= 0,
              width > 0,
              height > 0,
              dataSize > 0,
              depth > 0
        else {
            throw ImageReaderError.invalid
        }
    }

    func readImage(_ reader: BinaryDataReader) throws -> NSBitmapImageRep {
        switch compressor {
        case Self.quickDraw:
            try reader.advance(bytesUntilData)
            return try Picture(reader).imageRep
        case Self.animation:
            return try QTAnimation.rep(for: self, reader: reader)
        case Self.none:
            return try QTNone.rep(for: self, reader: reader)
        case Self.planar:
            return try QTPlanar.rep(for: self, reader: reader)
        default:
            // Attempt to let the system decode it. This should work for e.g. PNG, JPEG, GIF, TIFF.
            try reader.advance(bytesUntilData)
            let data = try reader.readData(length: Int(dataSize))
            guard let rep = NSBitmapImageRep(data: data) else {
                throw ImageReaderError.unsupported
            }
            if compressor == Self.png {
                // Older QuickTime versions (<6.5) stored png data as non-standard RGBX
                // We need to disable the alpha, but first ensure the image has been decoded by accessing the bitmapData
                _ = rep.bitmapData
                rep.hasAlpha = false
            }
            return rep
        }
    }

    /// Construct a PixMap than can be used to blit pixel data.
    func blitter(rowBytes: Int) -> PixelMap {
        return PixelMap(rowBytes: rowBytes,
                        bounds: QDRect(bottom: Int(height), right: Int(width)),
                        pixelSize: Int16(resolvedDepth))
    }
}

extension QTImageDesc {
    func write(_ writer: BinaryDataWriter) throws {
        writer.write(size)
        writer.write(compressor)
        writer.advance(4 + 2 + 2) // reserved, reserved, dataRefIndex
        writer.write(version)
        writer.write(revisionLevel)
        writer.write(vendor)
        writer.advance(4 + 4) // temporalQuality, spatialQuality
        writer.write(width)
        writer.write(height)
        writer.write(hRes)
        writer.write(vRes)
        writer.write(dataSize)
        writer.write(frameCount)
        try writer.writePString(name, fixedSize: 32)
        writer.write(depth)
        writer.write(clutID)
    }

    static func write(rep: NSBitmapImageRep, to writer: BinaryDataWriter, using compressor: UInt32) throws {
        let name: String
        let compressed: Data
        switch compressor {
        case Self.png:
            name = "PNG"
            compressed = rep.representation(using: .png, properties: [:])!
        case Self.jpeg:
            name = "Photo - JPEG"
            compressed = rep.representation(using: .jpeg, properties: [:])!
        default:
            throw ImageWriterError.unsupported
        }
        guard rep.pixelsWide <= Int16.max, rep.pixelsHigh <= Int16.max else {
            throw ImageWriterError.tooBig
        }
        let imageDesc = QTImageDesc(compressor: compressor,
                                    width: Int16(rep.pixelsWide),
                                    height: Int16(rep.pixelsHigh),
                                    dataSize: UInt32(compressed.count),
                                    name: name,
                                    depth: 24)
        try imageDesc.write(writer)
        writer.writeData(compressed)
    }
}
