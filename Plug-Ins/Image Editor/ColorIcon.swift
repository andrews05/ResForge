import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/More_Mac_Toolbox/Icon_Utilities.pdf#page=15

struct ColorIcon {
    var imageRep: NSBitmapImageRep
    var format: UInt32 = 0
}

extension ColorIcon {
    init(_ reader: BinaryDataReader) throws {
        let pixMap = try QDPixMap(reader)
        let maskMap = try QDPixMap(reader)
        let bitMap = try QDPixMap(reader)
        try reader.advance(4) // Skip data handle
        let maskSize = maskMap.bytesPerRow * maskMap.bounds.height
        let mask = try reader.readData(length: maskSize)
        let bitmapSize = bitMap.bytesPerRow * bitMap.bounds.height
        try reader.advance(bitmapSize) // Skip bitmap data
        let colorTable = try ColorTable.read(reader)
        let pixelData = try reader.readData(length: pixMap.pixelDataSize)

        imageRep = try pixMap.imageRep(pixelData: pixelData, colorTable: colorTable, mask: mask)
        format = UInt32(pixMap.pixelSize)
    }

    mutating func write(_ writer: BinaryDataWriter) throws {
        imageRep = QDPixMap.normalizeRep(imageRep)
        let (pixMap, pixelData, palette) = QDPixMap.build(from: imageRep)
        let maskRowBytes = (imageRep.pixelsWide + 7) / 8
        let maskMap = QDPixMap(rowBytes: UInt16(maskRowBytes), bounds: pixMap.bounds)
        let mask = QDPixMap.buildMask(from: imageRep)
        pixMap.write(writer)
        maskMap.write(writer)
        maskMap.write(writer) // Repeat maskMap for bitMap
        writer.advance(4) // Skip data handle
        writer.writeData(mask)
        writer.advance(maskRowBytes * imageRep.pixelsHigh) // Skip bitmap data
        ColorTable.write(writer, colors: palette)
        writer.writeData(pixelData)
        format = UInt32(pixMap.pixelSize)
    }

    static func rep(_ data: Data, format: inout UInt32) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let cicn = try? Self(reader) else {
            return nil
        }
        format = cicn.format
        return cicn.imageRep
    }

    static func data(from rep: NSBitmapImageRep, format: inout UInt32) -> Data {
        var cicn = Self(imageRep: rep)
        let writer = BinaryDataWriter()
        try? cicn.write(writer)
        format = cicn.format
        return writer.data
    }
}
