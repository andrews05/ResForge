import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=334

struct PixelPattern {
    let format: ImageFormat
    private let pixMap: PixelMap
    private let colorTable: [RGBColor]
    private let pixelData: Data
}

extension PixelPattern {
    init(_ reader: BinaryDataReader) throws {
        let pos = reader.bytesRead
        let pixPat = try QDPixPat(reader)
        try reader.setPosition(pos + Int(pixPat.patMap))
        pixMap = try PixelMap(reader)
        try reader.setPosition(pos + Int(pixMap.pmTable))
        colorTable = try ColorTable.read(reader)
        try reader.setPosition(pos + Int(pixPat.patData))
        pixelData = try reader.readData(length: pixMap.pixelDataSize)
        format = pixMap.format
    }

    init(imageRep: NSBitmapImageRep) throws {
        var (pixMap, pixelData, colorTable) = try PixelMap.build(from: imageRep)
        pixMap.pmTable = QDPixPat.size + PixelMap.size + UInt32(pixelData.count)
        self.pixMap = pixMap
        self.pixelData = pixelData
        self.colorTable = colorTable
        format = pixMap.format
    }

    mutating func write(_ writer: BinaryDataWriter) throws {
        let pixPat = QDPixPat()
        pixPat.write(writer)
        pixMap.write(writer)
        writer.writeData(pixelData)
        ColorTable.write(writer, colors: colorTable)
    }

    static func rep(_ data: Data, format: inout ImageFormat) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let ppat = try? Self(reader) else {
            return nil
        }
        format = ppat.format
        return try? ppat.pixMap.imageRep(pixelData: ppat.pixelData, colorTable: ppat.colorTable)
    }

    static func multiRep(_ data: Data, format: inout ImageFormat) -> NSBitmapImageRep? {
        do {
            let reader = BinaryDataReader(data)
            let count = Int(try reader.read() as Int16)
            guard count > 0 else {
                return nil
            }
            var offsets: [Int] = []
            for _ in 0..<count {
                offsets.append(Int(try reader.read() as UInt32))
            }

            // Read first ppat
            try reader.setPosition(offsets[0])
            let ppat = try Self(reader)
            format = ppat.format

            // Determine grid size
            let width = ppat.pixMap.bounds.width
            let height = ppat.pixMap.bounds.height
            let maxColumns = max(64 / width, 4)
            let gridX = min(count, maxColumns)
            let gridY = (count + maxColumns - 1) / maxColumns

            // Construct a rep and draw the first ppat
            let rep = ImageFormat.rgbaRep(width: width * gridX, height: height * gridY)
            var destRect = QDRect(bottom: height, right: width)
            try ppat.pixMap.draw(ppat.pixelData, colorTable: ppat.colorTable, to: rep, in: destRect)

            // Read and draw remaining ppats - assume they're all the same size as the first
            for offset in offsets[1...] {
                try reader.setPosition(offset)
                if destRect.right == rep.pixelsWide {
                    destRect.top = destRect.bottom
                    destRect.bottom += height
                    destRect.left = 0
                    destRect.right = width
                } else {
                    destRect.left = destRect.right
                    destRect.right += width
                }
                let ppat = try Self(reader)
                try ppat.pixMap.draw(ppat.pixelData, colorTable: ppat.colorTable, to: rep, in: destRect)
            }
            return rep
        } catch {
            return nil
        }
    }

    static func data(from rep: NSBitmapImageRep, format: inout ImageFormat) throws -> Data {
        var ppat = try Self(imageRep: rep)
        let writer = BinaryDataWriter()
        try ppat.write(writer)
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
    var patData: UInt32 = Self.size + PixelMap.size
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
            throw ImageReaderError.invalid
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
