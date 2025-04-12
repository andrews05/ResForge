import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=378
// https://developer.apple.com/library/archive/documentation/mac/pdf/More_Mac_Toolbox/Icon_Utilities.pdf#page=15

struct ColorIcon {
    var imageRep: NSBitmapImageRep
    var format: ImageFormat = .unknown
}

extension ColorIcon {
    init(_ reader: BinaryDataReader) throws {
        let pixMap = try PixelMap(reader)
        let maskMap = try PixelMap(reader)
        let bitMap = try PixelMap(reader)
        try reader.advance(4) // Skip data handle
        let mask = try reader.readData(length: maskMap.pixelDataSize)
        try reader.advance(bitMap.pixelDataSize) // Skip bitmap data
        let colorTable = try ColorTable.read(reader)
        let pixelData = try reader.readData(length: pixMap.pixelDataSize)

        imageRep = try pixMap.imageRep(pixelData: pixelData, colorTable: colorTable)
        try maskMap.applyMask(mask, to: imageRep)
        format = pixMap.format
    }

    mutating func write(_ writer: BinaryDataWriter) throws {
        imageRep = ImageFormat.normalize(imageRep)
        let (pixMap, pixelData, palette) = try PixelMap.build(from: imageRep)
        let maskRowBytes = (imageRep.pixelsWide + 7) / 8
        let maskMap = PixelMap(rowBytes: maskRowBytes, bounds: pixMap.bounds)
        let mask = PixelMap.buildMask(from: imageRep)
        pixMap.write(writer)
        maskMap.write(writer)
        maskMap.write(writer) // Repeat maskMap for bitMap
        writer.advance(4) // Skip data handle
        writer.writeData(mask)
        writer.advance(maskRowBytes * imageRep.pixelsHigh) // Skip bitmap data
        ColorTable.write(writer, colors: palette)
        writer.writeData(pixelData)
        format = pixMap.format
    }

    static func rep(_ data: Data, format: inout ImageFormat) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let cicn = try? Self(reader) else {
            return nil
        }
        format = cicn.format
        return cicn.imageRep
    }

    static func data(from rep: NSBitmapImageRep, format: inout ImageFormat) throws -> Data {
        var cicn = Self(imageRep: rep)
        let writer = BinaryDataWriter()
        try cicn.write(writer)
        format = cicn.format
        return writer.data
    }
}
