import AppKit
import RFSupport
import OrderedCollections

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=322

struct PixelMap {
    static let size: UInt32 = 50
    static let pixmap: UInt16 = 0x8000
    static let rgbDirect: Int16 = 16

    var baseAddr: UInt32 = 0
    var rowBytes = 0
    var isPixmap = false
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

extension PixelMap {
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
    var format: ImageFormat {
        if !isPixmap {
            .monochrome
        } else if pixelSize == 32 {
            // Show 24 if only 3 components are stored
            .color(Int(cmpCount * cmpSize))
        } else {
            .color(Int(pixelSize))
        }
    }

    init(_ reader: BinaryDataReader, skipBaseAddr: Bool = false) throws {
        if !skipBaseAddr {
            baseAddr = try reader.read()
        }
        let rowBytesAndFlags = try reader.read() as UInt16
        rowBytes = Int(rowBytesAndFlags & 0x3FFF)
        isPixmap = rowBytesAndFlags & Self.pixmap == Self.pixmap
        bounds = try QDRect(reader)

        // If the PixMap is actually a BitMap, don't read any further
        if isPixmap {
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
        }

        guard bounds.isValid,
              pmVersion == 0 || pmVersion == 4,
              packSize == 0
        else {
            throw ImageReaderError.invalid
        }

        switch pixelSize {
        case 1, 2, 4, 8:
            guard pixelType == 0 else {
                throw ImageReaderError.invalid
            }
        case 16:
            guard packType == .none || packType == .rlePixel,
                  pixelType == Self.rgbDirect
            else {
                throw ImageReaderError.invalid
            }
        case 32:
            guard packType == .none || packType == .dropPadByte || packType == .rleComponent,
                  pixelType == Self.rgbDirect,
                  cmpCount == 3 || cmpCount == 4,
                  cmpSize == 8
            else {
                throw ImageReaderError.invalid
            }
        default:
            throw ImageReaderError.invalid
        }
    }

    func imageRep(pixelData: Data, colorTable: [RGBColor]? = nil) throws -> NSBitmapImageRep {
        let rep = ImageFormat.rgbaRep(width: bounds.width, height: bounds.height)
        try self._draw(pixelData, colorTable: colorTable, to: rep)
        return rep
    }

    func draw(_ pixelData: Data, colorTable: [RGBColor]? = nil, to rep: NSBitmapImageRep, in destRect: QDRect, from srcRect: QDRect? = nil) throws {
        var srcRect = srcRect ?? bounds
        guard destRect.top >= 0,
              destRect.left >= 0,
              destRect.bottom <= rep.pixelsHigh,
              destRect.right <= rep.pixelsWide,
              bounds.contains(srcRect)
        else {
            throw ImageReaderError.invalid
        }

        // Align source rect to bounds
        srcRect.alignTo(bounds.origin)

        if srcRect.width == destRect.width && srcRect.height == destRect.height {
            try self._draw(pixelData, colorTable: colorTable, to: rep, in: destRect, from: srcRect)
        } else {
            // Scaling required - first draw to a temp rep then redraw to the target
            let tmpRep = ImageFormat.rgbaRep(width: srcRect.width, height: srcRect.height)
            try self._draw(pixelData, colorTable: colorTable, to: tmpRep, from: srcRect)
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSGraphicsContext.current?.imageInterpolation = .none
            tmpRep.draw(in: destRect.nsRect(in: rep))
        }
    }

    // Direct draw - rects are not validated
    private func _draw(_ pixelData: Data, colorTable: [RGBColor]? = nil, to rep: NSBitmapImageRep, in destRect: QDRect? = nil, from srcRect: QDRect? = nil) throws {
        guard rowBytes >= (bounds.width * Int(pixelSize) + 7) / 8,
              pixelData.count >= pixelDataSize
        else {
            throw ImageReaderError.invalid
        }

        let srcRect = srcRect ?? QDRect(bottom: bounds.height, right: bounds.width)
        let yRange = srcRect.top..<srcRect.bottom
        let xRange = srcRect.left..<srcRect.right
        var bitmap = rep.bitmapData!
        if let destRect {
            bitmap += destRect.top * rep.bytesPerRow + destRect.left * 4
        }
        let rowBytes = resolvedRowBytes

        // Access the raw pixel buffer for best performance
        try pixelData.withUnsafeBytes { (pixelData: UnsafeRawBufferPointer) in
            switch pixelSize {
            case 1, 2, 4:
                guard let colorTable, colorTable.count >= 1 << pixelSize else {
                    throw ImageReaderError.invalid
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
                    throw ImageReaderError.invalid
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
                throw ImageReaderError.invalid
            }
        }
    }

    func applyMask(_ mask: Data, to rep: NSBitmapImageRep) throws {
        try Self.applyMask(mask, to: rep, rowBytes: rowBytes)
    }

    static func applyMask(_ mask: Data, to rep: NSBitmapImageRep, rowBytes: Int) throws {
        guard rowBytes >= (rep.pixelsWide + 7) / 8,
              mask.count == rowBytes * rep.pixelsHigh
        else {
            throw ImageReaderError.invalid
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
                bitmap += 4
            }
        }
    }
}

// MARK: Writer

extension PixelMap {
    init(for rep: NSBitmapImageRep, rgb555: Bool = false) throws {
        bounds = try QDRect(for: rep)
        rowBytes = rep.pixelsWide * (rgb555 ? 2 : 4)
        guard rowBytes < 0x4000 else {
            throw ImageWriterError.tooBig
        }

        baseAddr = 0x000000FF // Not required but standard practice
        isPixmap = true
        packType = rgb555 ? .rlePixel : .rleComponent
        pixelType = Self.rgbDirect
        pixelSize = rgb555 ? 16 : 32
        cmpCount = 3
        cmpSize = rgb555 ? 5 : 8
    }

    func write(_ writer: BinaryDataWriter, skipBaseAddr: Bool = false) {
        if !skipBaseAddr {
            writer.write(baseAddr)
        }
        var rowBytesAndFlags = UInt16(rowBytes)
        if isPixmap {
            rowBytesAndFlags |= Self.pixmap
        }
        writer.write(rowBytesAndFlags)
        bounds.write(writer)

        // If the PixMap is actually a BitMap, don't write any more
        if isPixmap {
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
    }

    static func build(from rep: NSBitmapImageRep, startingColors: [RGBColor]? = nil) throws -> (pixMap: Self, pixelData: Data, colorTable: [RGBColor]) {
        let rep = ImageFormat.normalize(rep)
        let bounds = try QDRect(for: rep)

        // Iterate the pixels as UInt32 and construct the color table and pixel data
        let pixelCount = rep.pixelsWide * rep.pixelsHigh
        var pixelData = Data(repeating: 0, count: pixelCount)
        var colorTable = OrderedSet<RGBColor>(startingColors ?? [])
        rep.bitmapData!.withMemoryRebound(to: RGBColor.self, capacity: pixelCount) { pixels in
            for i in 0..<pixelCount {
                // Skip transparent pixels - this can avoid storing unnecessary colors in the palette
                if !rep.hasAlpha || pixels[i].alpha != 0 {
                    let (_, index) = colorTable.append(pixels[i])
                    pixelData[i] = UInt8(index)
                }
            }
        }

        // Determine minimum depth and row bytes
        let pixelSize = switch colorTable.count {
        case ...2: 1
        case ...4: 2
        case ...16: 4
        case ...256: 8
        default:
            throw ImageWriterError.tooManyColors
        }
        let rowBytes = (rep.pixelsWide * pixelSize + 7) / 8
        guard rowBytes < 0x4000 else {
            throw ImageWriterError.tooBig
        }

        // Rewrite data if below 8-bit
        if pixelSize < 8 {
            let mod = 8 / pixelSize
            let diff = 8 - pixelSize
            var newData = Data(capacity: rowBytes * rep.pixelsHigh)

            for y in 0..<rep.pixelsHigh {
                var scratch: UInt8 = 0
                for x in 0..<rep.pixelsWide {
                    let pxNum = x % mod
                    if pxNum == 0 && x != 0 {
                        newData.append(scratch)
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
        let pixMap = Self(rowBytes: rowBytes,
                          isPixmap: true,
                          bounds: bounds,
                          pixelType: 0,
                          pixelSize: Int16(pixelSize),
                          cmpCount: 1,
                          cmpSize: Int16(pixelSize))
        return (pixMap, pixelData, Array(colorTable))
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
                    mask.append(scratch)
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
}
