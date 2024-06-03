import AppKit
import RFSupport
import OrderedCollections

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=322

struct QDPixMap {
    static let size: UInt32 = 50
    static let pixmap: UInt16 = 0x8000
    static let rgbDirect: Int16 = 16

    var baseAddr: UInt32 = 0
    var rowBytesAndFlags: UInt16
    var bounds: QDRect
    var pmVersion: Int16 = 0
    var packType: PackType = .default
    var packSize: Int32 = 0
    var hRes: UInt32 = 0x00480000
    var vRes: UInt32 = 0x00480000
    var pixelType: Int16 = 0
    var pixelSize: Int16 = 1
    var cmpCount: Int16 = 1
    var cmpSize: Int16 = 1
    var planeBytes: Int32 = 0
    var pmTable: UInt32 = 0
    var pmReserved: UInt32 = 0
}

extension QDPixMap {
    var isPixmap: Bool {
        rowBytesAndFlags & Self.pixmap == Self.pixmap
    }
    /// The underlying number of row bytes, excluding flag bits.
    var rowBytes: Int {
        // 2 high bits are flags
        Int(rowBytesAndFlags & 0x3FFF)
    }
    /// For direct pixels, the actual packing type used.
    var resolvedPackType: PackType {
        // Row bytes less than 8 is never packed
        rowBytes < 8 ? .none : packType
    }
    /// The actual number of expected row bytes in the unpacked pixel data.
    var resolvedRowBytes: Int {
        if pixelSize == 32 {
            switch resolvedPackType {
            case .rleComponent where cmpCount == 3, .dropPadByte:
                return rowBytes / 4 * 3
            default:
                break
            }
        }
        return rowBytes
    }
    /// The total expected size of the unpacked pixel data.
    var pixelDataSize: Int {
        bounds.height * resolvedRowBytes
    }

    init(_ reader: BinaryDataReader, skipBaseAddr: Bool = false) throws {
        if !skipBaseAddr {
            baseAddr = try reader.read()
        }
        rowBytesAndFlags = try reader.read()
        bounds = try QDRect(reader)

        // If the PixMap is actually a BitMap, don't read any further
        if isPixmap {
            pmVersion = try reader.read()
            packType = try PackType.read(reader)
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
        }

        guard pmVersion == 0 || pmVersion == 4,
              packSize == 0,
              rowBytes >= (bounds.width * Int(pixelSize) + 7) / 8
        else {
            throw ImageReaderError.invalidData
        }

        switch pixelSize {
        case 1, 2, 4, 8:
            guard pixelType == 0 else {
                throw ImageReaderError.invalidData
            }
        case 16:
            guard packType == .none || packType == .rlePixel,
                  pixelType == Self.rgbDirect
            else {
                throw ImageReaderError.invalidData
            }
        case 32:
            guard packType == .none || packType == .dropPadByte || packType == .rleComponent,
                  pixelType == Self.rgbDirect,
                  cmpCount == 3 || cmpCount == 4,
                  cmpSize == 8
            else {
                throw ImageReaderError.invalidData
            }
        default:
            throw ImageReaderError.invalidData
        }
    }

    func write(_ writer: BinaryDataWriter, skipBaseAddr: Bool = false) {
        if !skipBaseAddr {
            writer.write(baseAddr)
        }
        writer.write(rowBytesAndFlags)
        bounds.write(writer)

        // If this is bitmap rather than a pixmap then stop here
        if rowBytesAndFlags & Self.pixmap == 0 {
            return
        }

        writer.write(pmVersion)
        writer.write(packType.rawValue)
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

    func imageRep(pixelData: Data, colorTable: [RGBColor]? = nil, mask: Data? = nil) throws -> NSBitmapImageRep {
        let rep = Self.rgbaRep(width: bounds.width, height: bounds.height)
        let destRect = QDRect(bottom: Int16(bounds.height), right: Int16(bounds.width))
        try self.draw(pixelData, colorTable: colorTable, to: rep, in: destRect, from: bounds)

        if let mask {
            try Self.applyMask(mask, to: rep)
        }

        return rep
    }

    func draw(_ pixelData: Data, colorTable: [RGBColor]? = nil, to rep: NSBitmapImageRep, in destRect: QDRect, from srcRect: QDRect) throws {
        guard pixelData.count >= pixelDataSize else {
            throw ImageReaderError.insufficientData
        }
        guard destRect.top >= 0,
              destRect.left >= 0,
              destRect.bottom <= rep.pixelsHigh,
              destRect.right <= rep.pixelsWide,
              bounds.contains(srcRect),
              srcRect.width == destRect.width,
              srcRect.height == destRect.height
        else {
            throw ImageReaderError.invalidData
        }

        // Align source rect to bounds
        var srcRect = srcRect
        try srcRect.alignTo(bounds.origin)

        let yRange = Int(srcRect.top)..<Int(srcRect.bottom)
        let xRange = Int(srcRect.left)..<Int(srcRect.right)
        var bitmap = rep.bitmapData! + Int(destRect.top) * rep.bytesPerRow + Int(destRect.left) * 4
        let rowBytes = resolvedRowBytes

        // Access the raw pixel buffer for best performance
        try pixelData.withUnsafeBytes { (pixelData: UnsafeRawBufferPointer) in
            switch pixelSize {
            case 1, 2, 4:
                guard let colorTable, colorTable.count >= 1 << pixelSize else {
                    throw ImageReaderError.invalidData
                }
                let depth = Int(pixelSize)
                let mod = 8 / depth
                let mask = (1 << depth) - 1
                let diff = 8 - depth

                for y in yRange {
                    let offset = y * rowBytes
                    for x in xRange {
                        let byte = Int(pixelData[offset + (x / mod)])
                        let byteShift = diff - ((x % mod) * depth)
                        let value = (byte >> byteShift) & mask
                        colorTable[value].draw(to: &bitmap)
                    }
                    bitmap += rep.bytesPerRow - (xRange.count * 4)
                }
            case 8:
                // Fast path for 8-bit
                guard let colorTable, colorTable.count >= 256 else {
                    throw ImageReaderError.invalidData
                }
                for y in yRange {
                    let offset = y * rowBytes
                    for x in xRange {
                        let value = Int(pixelData[offset + x])
                        colorTable[value].draw(to: &bitmap)
                    }
                    bitmap += rep.bytesPerRow - (xRange.count * 4)
                }
            case 16:
                for y in yRange {
                    let offset = y * rowBytes
                    for x in xRange {
                        RGBColor(pixelData[offset + x * 2], pixelData[offset + x * 2 + 1]).draw(to: &bitmap)
                    }
                    bitmap += rep.bytesPerRow - (xRange.count * 4)
                }
            case 32 where resolvedPackType == .rleComponent:
                let skip = cmpCount == 4 ? bounds.width : 0
                for y in yRange {
                    let offset = y * rowBytes + skip
                    for x in xRange {
                        bitmap[0] = pixelData[offset + x]
                        bitmap[1] = pixelData[offset + x + bounds.width]
                        bitmap[2] = pixelData[offset + x + bounds.width * 2]
                        bitmap[3] = 0xFF
                        bitmap += 4
                    }
                    bitmap += rep.bytesPerRow - (xRange.count * 4)
                }
            case 24, 32:
                // Don't rely on the given component count here - determine it from the pack type
                let cmpCount = pixelSize == 24 || resolvedPackType == .dropPadByte ? 3 : 4
                for y in yRange {
                    let offset = y * rowBytes + cmpCount - 3
                    for x in xRange {
                        bitmap[0] = pixelData[offset + x * cmpCount]
                        bitmap[1] = pixelData[offset + x * cmpCount + 1]
                        bitmap[2] = pixelData[offset + x * cmpCount + 2]
                        bitmap[3] = 0xFF
                        bitmap += 4
                    }
                    bitmap += rep.bytesPerRow - (xRange.count * 4)
                }
            default:
                throw ImageReaderError.unsupported
            }
        }
    }

    static func applyMask(_ mask: Data, to rep: NSBitmapImageRep) throws {
        let rowBytes = (rep.pixelsWide + 7) / 8
        guard mask.count == rowBytes * rep.pixelsHigh else {
            throw ImageReaderError.invalidData
        }
        // Loop over the pixels and set the alpha component according to the mask
        var bitmap = rep.bitmapData!
        for y in 0..<rep.pixelsHigh {
            let offset = mask.startIndex + y * rowBytes
            for x in 0..<rep.pixelsWide {
                let byte = Int(mask[offset + (x / 8)])
                let byteShift = 7 - (x % 8)
                let value = (byte >> byteShift) & 0x1
                bitmap[3] = value == 0 ? 0 : 0xFF
                bitmap += 4;
            }
        }
    }

    static func build(from rep: NSBitmapImageRep) -> (pixMap: Self, pixelData: Data, colorTable: OrderedSet<UInt32>) {
        let rep = Self.normalizeRep(rep)

        // Iterate the pixels as UInt32 and construct the color table and pixel data
        let pixelCount = rep.pixelsWide * rep.pixelsHigh
        var pixelData = Data(repeating: 0, count: pixelCount)
        var colorTable = OrderedSet<UInt32>()
        rep.bitmapData!.withMemoryRebound(to: UInt32.self, capacity: pixelCount) { pixels in
            for i in 0..<pixelCount {
                // Skip transparent pixels - this can avoid storing unnecessary colors in the palette
                if !rep.hasAlpha || UInt32(bigEndian: pixels[i]) & 0xFF != 0 {
                    let (_, index) = colorTable.append(pixels[i])
                    pixelData[i] = UInt8(index)
                }
            }
        }

        // Attempt to reduce depth
        var pixelSize = 8
        var rowBytes = rep.pixelsWide
        if colorTable.count <= 16 {
            switch colorTable.count {
            case ...2: pixelSize = 1
            case ...4: pixelSize = 2
            default: pixelSize = 4
            }

            let mod = 8 / pixelSize
            rowBytes = ((rowBytes - 1) / mod) + 1
            let diff = 8 - pixelSize
            var newData = Data(capacity: rowBytes * rep.pixelsHigh)

            for y in 0..<rep.pixelsHigh {
                var scratch: UInt8 = 0
                for x in 0..<rep.pixelsWide {
                    let pxNum = x % mod
                    if pxNum == 0 && x != 0 {
                        newData.append(scratch);
                        scratch = 0
                    }
                    let value = pixelData[y * rep.pixelsWide + x]
                    scratch |= value << (diff - (pxNum * pixelSize))
                }
                newData.append(scratch)
            }
            pixelData = newData
        }

        // Create the PixMap
        let pixMap = Self(rowBytesAndFlags: UInt16(rowBytes) | Self.pixmap,
                          bounds: QDRect(bottom: Int16(rep.pixelsHigh), right: Int16(rep.pixelsWide)),
                          pixelType: 0,
                          pixelSize: Int16(pixelSize),
                          cmpCount: 1,
                          cmpSize: Int16(pixelSize))
        return (pixMap, pixelData, colorTable)
    }

    static func buildMask(from rep: NSBitmapImageRep) -> Data {
        let rowBytes = (rep.pixelsWide + 7) / 8
        var mask = Data(capacity: rowBytes * rep.pixelsHigh)
        var bitmap = rep.bitmapData!
        for _ in 0..<rep.pixelsHigh {
            var scratch: UInt8 = 0
            for x in 0..<rep.pixelsWide {
                let pxNum = x % 8
                if pxNum == 0 && x != 0 {
                    mask.append(scratch);
                    scratch = 0
                }
                let value: UInt8 = bitmap[3] == 0 ? 0 : 1
                scratch |= value << (7 - pxNum)
                bitmap += 4
            }
            mask.append(scratch)
        }
        return mask
    }

    static func normalizeRep(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
        // Ensure 32-bit RGBA
        if rep.bitsPerPixel == 32 && rep.colorSpace.colorSpaceModel == .rgb {
            return rep
        }
        let newRep = self.rgbaRep(width: rep.pixelsWide, height: rep.pixelsHigh)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: newRep)
        rep.draw()
        NSGraphicsContext.restoreGraphicsState()
        return newRep
    }

    static func rgbaRep(width: Int, height: Int) -> NSBitmapImageRep {
        return NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: width,
                                pixelsHigh: height,
                                bitsPerSample: 8,
                                samplesPerPixel: 4,
                                hasAlpha: true,
                                isPlanar: false,
                                colorSpaceName: .deviceRGB,
                                bytesPerRow: width * 4,
                                bitsPerPixel: 0)!
    }
}

enum PackType: Int16 {
    /// Use default packing—type 3 for 16-bit pixels, type 4 for 32-bit pixels
    case `default` = 0
    /// Use no packing
    case none = 1
    /// Remove pad byte—supported only for 32-bit pixels (24-bit data)
    case dropPadByte = 2
    /// Run length encoding by pixelSize chunks, one scan line at a time—supported only for 16-bit pixels
    case rlePixel = 3
    /// Run length encoding one component at a time, one scan line at a time, red component first—supported only for 32-bit pixels (24-bit data)
    case rleComponent = 4

    static func read(_ reader: BinaryDataReader) throws -> Self {
        guard let packType = Self.init(rawValue: try reader.read()) else {
            throw ImageReaderError.invalidData
        }
        return packType
    }
}
