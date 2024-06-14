import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=590

struct ColorCursor {
    var imageRep: NSBitmapImageRep
    var format: ImageFormat
}

extension ColorCursor {
    init(_ reader: BinaryDataReader) throws {
        let crsr = try QDCCrsr(reader)
        try reader.setPosition(Int(crsr.crsrMap))
        let pixMap = try PixelMap(reader)
        try reader.setPosition(Int(pixMap.pmTable))
        let colorTable = try ColorTable.read(reader)
        try reader.setPosition(Int(crsr.crsrData))
        let pixelData = try reader.readData(length: pixMap.pixelDataSize)
        imageRep = try pixMap.imageRep(pixelData: pixelData, colorTable: colorTable, mask: crsr.crsrMask)
        format = pixMap.format
    }

    static func rep(_ data: Data, format: inout ImageFormat) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let crsr = try? Self(reader) else {
            return nil
        }
        format = crsr.format
        return crsr.imageRep
    }
}

struct QDCCrsr {
    static let size: UInt32 = 96
    static let typeMono: UInt16 = 0x8000
    static let typeColor: UInt16 = 0x8001
    var crsrType: UInt16 = Self.typeColor
    var crsrMap: UInt32 = Self.size
    var crsrData: UInt32 = Self.size + PixelMap.size
    var crsrXData: UInt32 = 0
    var crsrXValid: Int16 = 0
    var crsrXHandle: UInt32 = 0
    var crsr1Data: Data
    var crsrMask: Data
    var crsrHotSpot: QDPoint
    var crsrXTable: UInt32 = 0
    var crsrID: UInt32 = 0
}

extension QDCCrsr {
    init(_ reader: BinaryDataReader) throws {
        crsrType = try reader.read()
        crsrMap = try reader.read()
        crsrData = try reader.read()
        crsrXData = try reader.read()
        crsrXValid = try reader.read()
        crsrXHandle = try reader.read()
        crsr1Data = try reader.readData(length: 32)
        crsrMask = try reader.readData(length: 32)
        crsrHotSpot = try QDPoint(reader)
        crsrXTable = try reader.read()
        crsrID = try reader.read()
        guard crsrType == Self.typeColor, crsrMap != 0, crsrData != 0 else {
            throw ImageReaderError.invalid
        }
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(crsrType)
        writer.write(crsrMap)
        writer.write(crsrData)
        writer.write(crsrXData)
        writer.write(crsrXValid)
        writer.write(crsrXHandle)
        writer.writeData(crsr1Data)
        writer.writeData(crsrMask)
        crsrHotSpot.write(writer)
        writer.write(crsrXTable)
        writer.write(crsrID)
    }
}
