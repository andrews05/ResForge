import RFSupport
import OrderedCollections

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=322

enum QuickDrawError: Error {
    case invalidData
    case insufficientData
}

struct QDPixMap {
    static let size: UInt32 = 50
    static let pixmap: UInt16 = 0x8000
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
    var bytesPerRow: Int {
        // 2 high bits are flags
        Int(rowBytes & 0x3FFF)
    }

    var pixelDataSize: Int {
        bounds.height * bytesPerRow
    }

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

    func imageRep(pixelData: Data, colorTable: [RGBColor]) throws -> NSBitmapImageRep {
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

    static func build(from rep: NSBitmapImageRep) -> (pixMap: Self, pixelData: Data, colorTable: OrderedSet<UInt32>) {
        let rep = Self.normalizeRep(rep)
        let pixelCount = rep.pixelsWide * rep.pixelsHigh
        var pixelData = Data(capacity: pixelCount)
        // Iterate the pixels as UInt32 and construct a color table
        var colorTable = OrderedSet<UInt32>()
        rep.bitmapData!.withMemoryRebound(to: UInt32.self, capacity: pixelCount) { pixels in
            for i in 0..<pixelCount {
                let (_, index) = colorTable.append(pixels[i])
                pixelData.append(UInt8(index))
            }
        }
        let pixMap = Self(rowBytes: UInt16(rep.pixelsWide) | Self.pixmap,
                          bounds: QDRect(bottom: Int16(rep.pixelsHigh), right: Int16(rep.pixelsWide)),
                          pixelType: 0,
                          pixelSize: 8,
                          cmpCount: 1,
                          cmpSize: 8)
        return (pixMap, pixelData, colorTable)
    }

    static func normalizeRep(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
        // Ensure 32-bit RGBA
        if rep.bitsPerPixel == 32 && rep.colorSpace.colorSpaceModel == .rgb {
            return rep
        }
        let newRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                      pixelsWide: rep.pixelsWide,
                                      pixelsHigh: rep.pixelsHigh,
                                      bitsPerSample: 32,
                                      samplesPerPixel: 4,
                                      hasAlpha: true,
                                      isPlanar: false,
                                      colorSpaceName: .deviceRGB,
                                      bytesPerRow: rep.pixelsWide * 4,
                                      bitsPerPixel: 32)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
        rep.draw()
        NSGraphicsContext.restoreGraphicsState()
        return newRep
    }
}


struct RGBColor: Hashable {
    var red: UInt8 = 0
    var green: UInt8 = 0
    var blue: UInt8 = 0
}

extension RGBColor {
    func draw(to bitmap: inout UnsafeMutablePointer<UInt8>) {
        bitmap[0] = red
        bitmap[1] = green
        bitmap[2] = blue
        bitmap += 3
    }
}

struct ColorTable {
    static let device: UInt16 = 0x8000

    static func read(_ reader: BinaryDataReader) throws -> [RGBColor] {
        try reader.advance(4) // skip seed
        let flags = try reader.read() as UInt16
        let device = flags == Self.device
        let size = Int(try reader.read() as Int16) + 1
        guard 0...256 ~= size else {
            throw QuickDrawError.invalidData
        }

        var colors = Array(repeating: RGBColor(), count: 256)
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

        return colors
    }

    static func write(_ writer: BinaryDataWriter, colors: OrderedSet<UInt32>) {
        writer.advance(6) // skip seed and flags
        writer.write(Int16(colors.count - 1))
        for (i, color) in colors.enumerated() {
            // Use the raw bytes of the UInt32
            withUnsafeBytes(of: color) {
                writer.write(Int16(i))
                writer.writeData(Data([$0[0], $0[0], $0[1], $0[1], $0[2], $0[2]]))
            }
        }
    }
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
