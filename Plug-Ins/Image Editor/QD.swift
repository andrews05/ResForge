import RFSupport
import OrderedCollections

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=322

enum QuickDrawError: Error {
    case invalidData
    case insufficientData
}

struct QDRect {
    var top: Int16 = 0
    var left: Int16 = 0
    var bottom: Int16
    var right: Int16
}

extension QDRect {
    init(_ reader: BinaryDataReader) throws {
        top = try reader.read()
        left = try reader.read()
        bottom = try reader.read()
        right = try reader.read()
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(top)
        writer.write(left)
        writer.write(bottom)
        writer.write(right)
    }

    var width: Int {
        Int(right) - Int(left)
    }
    var height: Int {
        Int(bottom) - Int(top)
    }
}

struct RGBColor: Hashable {
    var red: UInt8 = 0
    var green: UInt8 = 0
    var blue: UInt8 = 0
}

extension RGBColor {
    init(from bitmap: inout UnsafeMutablePointer<UInt8>) {
        red = bitmap[0]
        green = bitmap[1]
        blue = bitmap[2]
        bitmap += 4
    }

    func draw(to bitmap: inout UnsafeMutablePointer<UInt8>) {
        bitmap[0] = red
        bitmap[1] = green
        bitmap[2] = blue
        bitmap += 3
    }
}

struct ColorTable {
    static let device: UInt16 = 0x8000
    var colors: [RGBColor]

    init(_ reader: BinaryDataReader) throws {
        try reader.advance(4) // skip seed
        let flags = try reader.read() as UInt16
        let device = flags == Self.device
        let size = Int(try reader.read() as Int16) + 1
        guard 0...256 ~= size else {
            throw QuickDrawError.invalidData
        }

        colors = Array(repeating: RGBColor(), count: 256)
        for i in 0..<size {
            let value = Int(try reader.read() as Int16)
            guard 0..<256 ~= value else {
                throw QuickDrawError.invalidData
            }
            // Take high bytes only
            let red = UInt8(try reader.read() as UInt16 >> 8)
            let green = UInt8(try reader.read() as UInt16 >> 8)
            let blue = UInt8(try reader.read() as UInt16 >> 8)
            colors[device ? i : value] = RGBColor(red: red, green: green, blue: blue)
        }
    }

    static func write(_ writer: BinaryDataWriter, colors: some Collection<RGBColor>) {
        writer.advance(6) // skip seed and flags
        writer.write(Int16(colors.count - 1))
        for (i, color) in colors.enumerated() {
            writer.write(Int16(i))
            writer.write(UInt16(color.red) << 8 | UInt16(color.red))
            writer.write(UInt16(color.green) << 8 | UInt16(color.green))
            writer.write(UInt16(color.blue) << 8 | UInt16(color.blue))
        }
    }

    subscript(_ index: Int) -> RGBColor {
        colors[index]
    }
}

struct QDPixMap {
    static let size: UInt32 = 50
    var baseAddr: UInt32 = 0
    var rowBytes: UInt16
    var bounds: QDRect
    var pmVersion: Int16 = 0
    var packType: Int16 = 0
    var packSize: Int32 = 0
    var hRes: UInt32 = 0x00480000
    var vRes: UInt32 = 0x00480000
    var pixelType: Int16
    var pixelSize: Int16
    var cmpCount: Int16
    var cmpSize: Int16
    var planeBytes: Int32 = 0
    var pmTable: UInt32 = 0
    var pmReserved: UInt32 = 0
}


extension QDPixMap {
    init(_ reader: BinaryDataReader) throws {
        baseAddr = try reader.read()
        rowBytes = try reader.read()
        bounds = try QDRect(reader)
        pmVersion = try reader.read()
        packType = try reader.read()
        packSize = try reader.read()
        hRes = try reader.read()
        vRes = try reader.read()
        pixelType = try reader.read()
        pixelSize = try reader.read()
        cmpCount = try reader.read()
        cmpSize = try reader.read()
        planeBytes = try reader.read()
        pmTable = try reader.read()
        pmReserved = try reader.read()

        guard pmVersion == 0 || pmVersion == 4,
              packType == 0,
              packSize == 0,
              pixelType == 0,
              pixelSize == 1 || pixelSize == 2 || pixelSize == 4 || pixelSize == 8,
              pmTable != 0,
              bytesPerRow >= bounds.width / (8 / Int(pixelSize))
        else {
            throw QuickDrawError.invalidData
        }
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(baseAddr)
        writer.write(rowBytes)
        bounds.write(writer)
        writer.write(pmVersion)
        writer.write(packType)
        writer.write(packSize)
        writer.write(hRes)
        writer.write(vRes)
        writer.write(pixelType)
        writer.write(pixelSize)
        writer.write(cmpCount)
        writer.write(cmpSize)
        writer.write(planeBytes)
        writer.write(pmTable)
        writer.write(pmReserved)
    }

    var bytesPerRow: Int {
        Int(rowBytes & 0x3FFF)
    }

    var pixelDataSize: Int {
        bounds.height * bytesPerRow
    }

    func imageRep(pixelData: Data, colorTable: ColorTable) throws -> NSBitmapImageRep {
        guard pixelData.count >= pixelDataSize else {
            throw QuickDrawError.insufficientData
        }
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: bounds.width,
                                   pixelsHigh: bounds.height,
                                   bitsPerSample: 8,
                                   samplesPerPixel: 3,
                                   hasAlpha: false,
                                   isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: bounds.width * 3,
                                   bitsPerPixel: 0)!
        var bitmap = rep.bitmapData!

        if pixelSize == 8 {
            // Fast path for 8-bit
            for y in 0..<rep.pixelsHigh {
                let offset = pixelData.startIndex + y * bytesPerRow
                for x in 0..<rep.pixelsWide {
                    let value = Int(pixelData[offset + x])
                    colorTable[value].draw(to: &bitmap)
                }
            }
        } else {
            let depth = Int(pixelSize)
            let mod = 8 / depth
            let mask = (1 << depth) - 1
            let diff = 8 - depth

            for y in 0..<rep.pixelsHigh {
                let offset = pixelData.startIndex + y * bytesPerRow
                for x in 0..<rep.pixelsWide {
                    let byte = Int(pixelData[offset + (x / mod)])
                    let byteShift = diff - ((x % mod) * depth)
                    let value = (byte >> byteShift) & mask
                    colorTable[value].draw(to: &bitmap)
                }
            }
        }

        return rep
    }
}

struct QDPixPat {
    static let size: UInt32 = 28
    var patType: Int16 = 1
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
        guard patType == 1, patMap != 0, patData != 0 else {
            throw QuickDrawError.invalidData
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

struct PixelPattern {
    var pixMap: QDPixMap
    var pixelData: Data
    var colors: any Collection<RGBColor>
    var imageRep: NSBitmapImageRep

    var format: UInt32 {
        UInt32(pixMap.pixelSize)
    }

    init(_ data: Data) throws {
        let reader = BinaryDataReader(data)
        let pixPat = try QDPixPat(reader)
        try reader.setPosition(Int(pixPat.patMap))
        pixMap = try QDPixMap(reader)
        try reader.setPosition(Int(pixMap.pmTable))
        let colorTable = try ColorTable(reader)
        try reader.setPosition(Int(pixPat.patData))
        pixelData = try reader.readData(length: pixMap.pixelDataSize)
        imageRep = try pixMap.imageRep(pixelData: pixelData, colorTable: colorTable)
        colors = colorTable.colors
    }

    init(from rep: NSBitmapImageRep) throws {
        imageRep = rep
        var colorSet = OrderedSet<RGBColor>()
        var bitmap = rep.bitmapData!
        pixelData = Data(capacity: rep.pixelsWide * rep.pixelsHigh)
        for _ in 0..<(rep.pixelsWide * rep.pixelsHigh) {
            let color = RGBColor(from: &bitmap)
            let (_, index) = colorSet.append(color)
            pixelData.append(UInt8(index))
        }
        pixMap = QDPixMap(rowBytes: UInt16(rep.pixelsWide) | 0x8000,
                          bounds: QDRect(bottom: Int16(rep.pixelsHigh), right: Int16(rep.pixelsWide)),
                          pixelType: 0,
                          pixelSize: 8,
                          cmpCount: 1,
                          cmpSize: 8,
                          pmTable: QDPixPat.size + QDPixMap.size + UInt32(pixelData.count))
        colors = colorSet
    }

    func write(_ writer: BinaryDataWriter) {
        let pixPat = QDPixPat()
        pixPat.write(writer)
        pixMap.write(writer)
        writer.writeData(pixelData)
        ColorTable.write(writer, colors: colors)
    }

    static func rep(_ data: Data, format: inout UInt32) -> NSBitmapImageRep? {
        guard let ppat = try? Self(data) else {
            return nil
        }
        format = ppat.format
        return ppat.imageRep
    }

    static func data(from rep: NSBitmapImageRep) -> Data {
        guard let ppat = try? Self(from: rep) else {
            return Data()
        }
        let writer = BinaryDataWriter()
        ppat.write(writer)
        return writer.data
    }
}
