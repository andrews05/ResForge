import AppKit
import RFSupport

struct PixelPattern {
    var imageRep: NSBitmapImageRep
    var format: UInt32 = 0
}

extension PixelPattern {
    init(_ reader: BinaryDataReader) throws {
        let pixPat = try QDPixPat(reader)
        try reader.setPosition(Int(pixPat.patMap))
        let pixMap = try QDPixMap(reader)
        try reader.setPosition(Int(pixMap.pmTable))
        let colorTable = try ColorTable.read(reader)
        try reader.setPosition(Int(pixPat.patData))
        let pixelData = try reader.readData(length: pixMap.pixelDataSize)
        imageRep = try pixMap.imageRep(pixelData: pixelData, colorTable: colorTable)
        format = UInt32(pixMap.pixelSize)
    }

    mutating func write(_ writer: BinaryDataWriter) throws {
        let pixPat = QDPixPat()
        var (pixMap, pixelData, palette) = QDPixMap.build(from: imageRep)
        pixMap.pmTable = QDPixPat.size + QDPixMap.size + UInt32(pixelData.count)
        pixPat.write(writer)
        pixMap.write(writer)
        writer.writeData(pixelData)
        ColorTable.write(writer, colors: palette)
        format = UInt32(pixMap.pixelSize)
    }

    static func rep(_ data: Data, format: inout UInt32) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let ppat = try? Self(reader) else {
            return nil
        }
        format = ppat.format
        return ppat.imageRep
    }

    static func data(from rep: NSBitmapImageRep, format: inout UInt32) -> Data {
        var ppat = Self(imageRep: rep)
        let writer = BinaryDataWriter()
        try? ppat.write(writer)
        format = ppat.format
        return writer.data
    }
}

struct QDPixPat {
    static let size: UInt32 = 28
    static let typeMono: UInt16 = 0x0000
    static let typeColor: UInt16 = 0x0001
    static let typeRGB: UInt16 = 0x0002
    var patType: UInt16 = Self.typeColor
    var patMap: UInt32 = Self.size
    var patData: UInt32 = Self.size + QDPixMap.size
    var patXData: UInt32 = 0
    var patXValid: Int16 = -1
    var patXMap: UInt32 = 0
    var pat1Data: UInt64 = 0
}

extension QDPixPat {
    init(_ reader: BinaryDataReader) throws {
        patType = try reader.read()
        patMap = try reader.read()
        patData = try reader.read()
        patXData = try reader.read()
        patXValid = try reader.read()
        patXMap = try reader.read()
        pat1Data = try reader.read()
        guard patType == Self.typeColor, patMap != 0, patData != 0 else {
            throw ImageReaderError.invalidData
        }
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(patType)
        writer.write(patMap)
        writer.write(patData)
        writer.write(patXData)
        writer.write(patXValid)
        writer.write(patXMap)
        writer.write(pat1Data)
    }
}
