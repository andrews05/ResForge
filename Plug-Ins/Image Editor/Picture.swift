import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=727

class Picture {
    static let version1: UInt16 = 0x1101 // 1-byte versionOp + version number
    static let version2: Int16 = -1
    static let extendedVersion2: Int16 = -2
    private var v1: Bool
    private var frame: QDRect
    private var clipRect: QDRect
    private var origin: QDPoint
    private var matteRep: NSBitmapImageRep?
    private var matteRect: QDRect?

    var imageRep: NSBitmapImageRep
    var format: ImageFormat = .unknown

    required init(_ reader: BinaryDataReader, decode: Bool = true) throws {
        try reader.advance(2) // v1 size
        frame = try QDRect(reader)

        let versionOp = try reader.read() as UInt16
        v1 = versionOp == Self.version1
        if !v1 {
            guard versionOp == PictOpcode.versionOp.rawValue,
                  try PictOpcode.read2(reader) == .version,
                  try PictOpcode.read2(reader) == .headerOp
            else {
                throw ImageReaderError.invalid
            }
            let headerVersion = try reader.read() as Int16
            if headerVersion == Self.extendedVersion2 {
                try reader.advance(2 + 4 + 4) // reserved, hRes, vRes
                // Set the frame to the source rect. This isn't strictly correct but it allows us
                // to decode some images which would otherwise fail due to mismatched frame sizes
                // (QuickDraw would normally scale such images to fit the frame).
                frame = try QDRect(reader)
                try reader.advance(4) // reserved
            } else {
                // headerVersion should be version2 at this point, but sometimes it isn't
                try reader.advance(2 + 16 + 4) // ??, fixed-point bounding box, reserved
            }
        }

        guard frame.isValid else {
            throw ImageReaderError.invalid
        }

        origin = frame.origin
        clipRect = frame
        imageRep = ImageFormat.rgbaRep(width: frame.width, height: frame.height)
        if decode {
            try self.decode(reader)
        }
    }

    required init(imageRep: NSBitmapImageRep) throws {
        self.imageRep = ImageFormat.normalize(imageRep)
        v1 = false
        frame = try QDRect(for: imageRep)
        clipRect = frame
        origin = frame.origin
    }
}

extension Picture {
    static func rep(_ data: Data, format: inout ImageFormat) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let pict = try? Self(reader, decode: false) else {
            return nil
        }
        do {
            try pict.decode(reader)
            format = pict.format
            return pict.imageRep
        } catch {
            // We may still be able to show the format even if decoding failed
            format = pict.format
            return nil
        }
    }

    private func decode(_ reader: BinaryDataReader) throws {
        var error: Error? = nil
        // Create an NSImage with flipped custom draw handler
        let size = NSSize(width: frame.width, height: frame.height)
        let img = NSImage(size: size, flipped: true) { _ in
            do {
                NSGraphicsContext.current?.imageInterpolation = .none
                NSGraphicsContext.current?.shouldAntialias = false
                try self.readOps(reader)
                return true
            } catch let err {
                error = err
                return false
            }
        }
        // Draw the image into the rep
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: imageRep)
        img.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        if let error {
            throw error
        }
    }

    private func readOps(_ reader: BinaryDataReader) throws {
        let readOp = v1 ? PictOpcode.read1 : PictOpcode.read2
    ops:while true {
            switch try readOp(reader) {
            case .opEndPicture:
                break ops
            case .clipRegion:
                try self.readClipRegion(reader)
            case .origin:
                try self.readOrigin(reader)
            case .bitsRect:
                try self.readIndirectBitsRect(reader, packed: false, withMaskRegion: false)
            case .bitsRegion:
                try self.readIndirectBitsRect(reader, packed: false, withMaskRegion: true)
            case .packBitsRect:
                try self.readIndirectBitsRect(reader, packed: true, withMaskRegion: false)
            case .packBitsRegion:
                try self.readIndirectBitsRect(reader, packed: true, withMaskRegion: true)
            case .directBitsRect:
                try self.readDirectBits(reader, withMaskRegion: false)
            case .directBitsRegion:
                try self.readDirectBits(reader, withMaskRegion: true)
            case .rgbFgColor:
                try self.readColor(reader).set()
            case .line:
                let from = try QDPoint(reader)
                let to = try QDPoint(reader)
                NSBezierPath.strokeLine(from: self.convert(from), to: self.convert(to))
            case .lineFrom:
                let to = try QDPoint(reader)
                NSBezierPath.strokeLine(from: self.convert(origin), to: self.convert(to))
            case .shortLine:
                let from = try QDPoint(reader)
                var to = from
                to.x += Int(try reader.read() as Int8)
                to.y += Int(try reader.read() as Int8)
                NSBezierPath.strokeLine(from: self.convert(from), to: self.convert(to))
            case .shortLineFrom:
                var to = origin
                to.x += Int(try reader.read() as Int8)
                to.y += Int(try reader.read() as Int8)
                NSBezierPath.strokeLine(from: self.convert(origin), to: self.convert(to))
            case .frameRect:
                var rect = try QDRect(reader)
                rect.alignTo(origin)
                // Inset by half the stroke width
                NSBezierPath.stroke(rect.nsRect.insetBy(dx: 0.5, dy: 0.5))
            case .nop, .hiliteMode, .defHilite,
                    .frameSameRect, .paintSameRect, .eraseSameRect, .invertSameRect, .fillSameRect:
                continue
            case .textFace:
                try reader.advance(1)
            case .textFont, .textMode, .penMode, .textSize, .shortComment:
                try reader.advance(2)
            case .penSize:
                try reader.advance(4)
            case .rgbBkCcolor, .hiliteColor, .opColor:
                try reader.advance(6)
            case .penPattern, .fillPattern,
                    .paintRect, .eraseRect, .invertRect, .fillRect:
                try reader.advance(8)
            case .longText:
                try self.sizedSkip(reader, pre: 4, byte: true)
            case .dhText, .dvText:
                try self.sizedSkip(reader, pre: 1, byte: true)
            case .dhdvText:
                try self.sizedSkip(reader, pre: 2, byte: true)
            case .fontName, .lineJustify, .glyphState:
                try self.sizedSkip(reader)
            case .frameRegion, .paintRegion, .eraseRegion, .invertRegion, .fillRegion:
                try self.skipRegion(reader)
            case .longComment:
                try self.sizedSkip(reader, pre: 2)
            case .compressedQuickTime:
                try self.readQuickTime(reader)
                // A successful QuickTime decode will replace the imageRep and we should stop processing.
                break ops
            case .uncompressedQuickTime:
                try self.readUncompressedQuickTime(reader)
            default:
                throw ImageReaderError.unsupported
            }
        }

        // If we reached the end and have nothing to show for it then we should fail
//        if case .unknown = format {
//            throw ImageReaderError.unsupported
//        }
    }

    private func readIndirectBitsRect(_ reader: BinaryDataReader, packed: Bool, withMaskRegion: Bool) throws {
        let pixMap = try PixelMap(reader, skipBaseAddr: true)
        format = pixMap.format
        let colorTable = if pixMap.isPixmap {
            try ColorTable.read(reader)
        } else {
            ColorTable.system1
        }

        var (srcRect, destRect) = try self.readSrcAndDestRects(reader)
        srcRect.alignTo(pixMap.bounds.origin)

        try reader.advance(2) // transfer mode
        if withMaskRegion {
            try self.skipRegion(reader)
        }

        // Row bytes less than 8 is never packed
        let pixelData = if packed && pixMap.rowBytes >= 8 {
            try PackBits<UInt8>.readRows(reader: reader, pixMap: pixMap)
        } else {
            try reader.readData(length: pixMap.pixelDataSize)
        }

        let rep = try pixMap.imageRep(pixelData: pixelData, colorTable: colorTable)
        self.applyMatte(to: rep, in: srcRect)
        rep.draw(in: destRect.nsRect, from: srcRect.nsRect, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func readDirectBits(_ reader: BinaryDataReader, withMaskRegion: Bool) throws {
        let pixMap = try PixelMap(reader)
        format = pixMap.format

        var (srcRect, destRect) = try self.readSrcAndDestRects(reader)
        srcRect.alignTo(pixMap.bounds.origin)

        try reader.advance(2) // transfer mode
        if withMaskRegion {
            try self.skipRegion(reader)
        }

        let pixelData = switch pixMap.resolvedPackType {
        case .rlePixel:
            try PackBits<UInt16>.readRows(reader: reader, pixMap: pixMap)
        case .rleComponent:
            try PackBits<UInt8>.readRows(reader: reader, pixMap: pixMap)
        default:
            try reader.readData(length: pixMap.pixelDataSize)
        }

        let rep = try pixMap.imageRep(pixelData: pixelData)
        self.applyMatte(to: rep, in: srcRect)
        rep.draw(in: destRect.nsRect, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func readSrcAndDestRects(_ reader: BinaryDataReader) throws -> (srcRect: QDRect, destRect: QDRect) {
        var srcRect = try QDRect(reader)
        var destRect = try QDRect(reader)
        // Apply clip rect to dest rect, adjusting source rect by matching amount
        if clipRect.top > destRect.top {
            srcRect.top += clipRect.top - destRect.top
            destRect.top = clipRect.top
        }
        if clipRect.left > destRect.left {
            srcRect.left += clipRect.left - destRect.left
            destRect.left = clipRect.left
        }
        if clipRect.bottom < destRect.bottom {
            srcRect.bottom -= destRect.bottom - clipRect.bottom
            destRect.bottom = clipRect.bottom
        }
        if clipRect.right < destRect.right {
            srcRect.right -= destRect.right - clipRect.right
            destRect.right = clipRect.right
        }
        guard srcRect.isValid, destRect.isValid else {
            throw ImageReaderError.invalid
        }
        // Align dest rect to the origin
        destRect.alignTo(origin)
        return (srcRect, destRect)
    }

    private func readClipRegion(_ reader: BinaryDataReader) throws {
        let length = Int(try reader.read() as UInt16)
        clipRect = try QDRect(reader)
        guard clipRect.isValid else {
            throw ImageReaderError.invalid
        }
        try reader.advance(length - 10)
    }

    private func readOrigin(_ reader: BinaryDataReader) throws {
        origin.x += Int(try reader.read() as Int16)
        origin.y += Int(try reader.read() as Int16)
    }

    private func readColor(_ reader: BinaryDataReader) throws -> NSColor {
        let data = try reader.readData(length: 6)
        return NSColor(deviceRed: Double(data[data.startIndex + 0]) / 255,
                       green: Double(data[data.startIndex + 2]) / 255,
                       blue: Double(data[data.startIndex + 4]) / 255,
                       alpha: 1)
    }

    private func convert(_ point: QDPoint) -> NSPoint {
        var p = point.nsPoint
        // Align to origin and offset by half the stroke width
        p.x += Double(origin.x) + 0.5
        p.y += Double(origin.y) + 0.5
        return p
    }

    private func skipRegion(_ reader: BinaryDataReader) throws {
        let length = Int(try reader.read() as UInt16)
        try reader.advance(length - 2)
    }

    private func sizedSkip(_ reader: BinaryDataReader, pre: Int = 0, byte: Bool = false) throws {
        try reader.advance(pre)
        let length = if byte {
            Int(try reader.read() as UInt8)
        } else {
            Int(try reader.read() as UInt16)
        }
        try reader.advance(length)
    }

    private func readQuickTime(_ reader: BinaryDataReader) throws {
        // https://vintageapple.org/inside_r/pdf/QuickTime_1993.pdf#484
        let size = Int(try reader.read() as UInt32)

        // Construct a new reader constrained to the specified size
        let reader = BinaryDataReader(try reader.readData(length: size))
        try reader.advance(2 + 36) // version, matrix
        let matteSize = Int(try reader.read() as UInt32)
        matteRect = try QDRect(reader)
        try reader.advance(2) // transferMode
        let srcRect = try QDRect(reader)
        try reader.advance(4) // accuracy
        let maskSize = Int(try reader.read() as UInt32)
        if matteSize > 0 {
            let matteReader = BinaryDataReader(try reader.readData(length: matteSize))
            matteRep = try QTImageDesc(matteReader).readImage(matteReader)
        }
        if maskSize > 0 {
            try reader.advance(maskSize)
        }

        let imageDesc = try QTImageDesc(reader)
        format = .quickTime(imageDesc.compressor, imageDesc.resolvedDepth)
        let rep = try imageDesc.readImage(reader)
        self.applyMatte(to: rep, in: srcRect)
        let destRect = NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
        rep.draw(in: destRect, from: srcRect.nsRect, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func readUncompressedQuickTime(_ reader: BinaryDataReader) throws {
        let size = Int(try reader.read() as UInt32)

        // Construct a new reader constrained to the specified size
        let reader = BinaryDataReader(try reader.readData(length: size))
        try reader.advance(2 + 36) // version, matrix
        let matteSize = Int(try reader.read() as UInt32)
        matteRect = try QDRect(reader)
        if matteSize > 0 {
            matteRep = try QTImageDesc(reader).readImage(reader)
        }
    }

    // Apply a QuickTime matte as an alpha mask for the rep
    private func applyMatte(to rep: NSBitmapImageRep, in rect: QDRect) {
        guard let matteRep, let matteRect else {
            return
        }
        // First convert the matte into an alpha channel
        let bitmap = matteRep.bitmapData!
        for i in 0..<(matteRep.pixelsWide * matteRep.pixelsHigh) {
            bitmap[i * 4 + 3] = 255 - bitmap[i * 4]
        }
        // Then draw it into the rep using destinationIn
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        matteRep.draw(in: rect.nsRect, from: matteRect.nsRect, operation: .destinationIn, fraction: 1, respectFlipped: true, hints: nil)
        NSGraphicsContext.restoreGraphicsState()
        format = .custom("\(format.description) + Matte")
        // Clear the matte so it doesn't get used again
        self.matteRep = nil
    }
}

// MARK: Writer

extension Picture {
    static func data(from rep: NSBitmapImageRep, format: inout ImageFormat) throws -> Data {
        let pict = try Self(imageRep: rep)
        let writer = BinaryDataWriter()
        try pict.write(writer, format: format)
        format = pict.format
        return writer.data
    }

    func write(_ writer: BinaryDataWriter, format: ImageFormat) throws {
        // Header
        writer.advance(2) // v1 size
        frame.write(writer)
        writer.write(PictOpcode.versionOp.rawValue)
        writer.write(PictOpcode.version.rawValue)
        writer.write(PictOpcode.headerOp.rawValue)
        writer.write(Self.extendedVersion2)
        writer.advance(2) // reserved
        writer.write(0x00480000 as UInt32) // hRes
        writer.write(0x00480000 as UInt32) // vRes
        frame.write(writer) // source rect
        writer.advance(4) // reserved

        // Clip region (required)
        writer.write(PictOpcode.clipRegion.rawValue)
        writer.write(10 as UInt16) // size
        clipRect.write(writer)

        // Image data
        self.format = format
        switch format {
        case .monochrome:
            try self.writeIndirectBits(writer, mono: true)
        case let .color(depth) where depth <= 8:
            try self.writeIndirectBits(writer)
        case .color(16):
            try self.writeDirectBits(writer, rgb555: true)
        case .color(24):
            try self.writeDirectBits(writer)
        case let .quickTime(compressor, _):
            try self.writeQuickTime(writer, compressor: compressor)
        default:
            throw ImageWriterError.unsupported
        }

        // Align and end
        writer.advance(writer.bytesWritten % 2)
        writer.write(PictOpcode.opEndPicture.rawValue)
    }

    private func writeIndirectBits(_ writer: BinaryDataWriter, mono: Bool = false) throws {
        writer.write(PictOpcode.packBitsRect.rawValue)
        var (pixMap, pixelData, colorTable) = try PixelMap.build(from: imageRep, startingColors: mono ? ColorTable.system1 : nil)
        if mono {
            guard colorTable.count == 2 else {
                throw ImageWriterError.tooManyColors
            }
            pixMap.isPixmap = false
            pixMap.write(writer, skipBaseAddr: true)
        } else {
            pixMap.write(writer, skipBaseAddr: true)
            ColorTable.write(writer, colors: colorTable)
        }
        pixMap.bounds.write(writer) // source rect
        frame.write(writer) // dest rect
        writer.advance(2) // transfer mode (0 = Source Copy)

        let rowBytes = pixMap.rowBytes
        if rowBytes >= 8 {
            pixelData.withUnsafeBytes { inBuffer in
                var input = inBuffer.assumingMemoryBound(to: UInt8.self).baseAddress!
                for _ in 0..<imageRep.pixelsHigh {
                    PackBits<UInt8>.writeRow(input, writer: writer, pixMap: pixMap)
                    input += rowBytes
                }
            }
        } else {
            writer.writeData(pixelData)
        }

        // Update format (may be different than what was specified)
        format = pixMap.format
    }

    private func writeDirectBits(_ writer: BinaryDataWriter, rgb555: Bool = false) throws {
        let pixMap = try PixelMap(for: imageRep, rgb555: rgb555)
        writer.write(PictOpcode.directBitsRect.rawValue)
        pixMap.write(writer)
        pixMap.bounds.write(writer) // source rect
        frame.write(writer) // dest rect
        writer.advance(2) // transfer mode (0 = Source Copy)

        var bitmap = imageRep.bitmapData!
        switch pixMap.resolvedPackType {
        case .rleComponent:
            withUnsafeTemporaryAllocation(of: UInt8.self, capacity: imageRep.pixelsWide * 3) { inBuffer in
                for _ in 0..<imageRep.pixelsHigh {
                    // Convert RGBA to channels
                    for x in 0..<imageRep.pixelsWide {
                        inBuffer[x] = bitmap[0]
                        inBuffer[x + imageRep.pixelsWide] = bitmap[1]
                        inBuffer[x + imageRep.pixelsWide * 2] = bitmap[2]
                        bitmap += 4
                    }
                    PackBits<UInt8>.writeRow(inBuffer.baseAddress!, writer: writer, pixMap: pixMap)
                }
            }
        case .rlePixel:
            withUnsafeTemporaryAllocation(of: UInt16.self, capacity: imageRep.pixelsWide) { inBuffer in
                for _ in 0..<imageRep.pixelsHigh {
                    // Convert RGBA to RGB555
                    for x in 0..<imageRep.pixelsWide {
                        inBuffer[x] = RGBColor(red: bitmap[0], green: bitmap[1], blue: bitmap[2]).rgb555().bigEndian
                        bitmap += 4
                    }
                    PackBits<UInt16>.writeRow(inBuffer.baseAddress!, writer: writer, pixMap: pixMap)
                }
            }
        case .none where pixMap.pixelSize == 16:
            // Convert RGBA to RGB555
            for _ in 0..<(imageRep.pixelsHigh * imageRep.pixelsWide) {
                writer.write(RGBColor(red: bitmap[0], green: bitmap[1], blue: bitmap[2]).rgb555())
                bitmap += 4
            }
        default:
            // Convert RGBA to XRGB by shifting the data 1 byte
            writer.advance(1)
            writer.data.append(bitmap, count: imageRep.bytesPerPlane-1)
        }
    }

    private func writeQuickTime(_ writer: BinaryDataWriter, compressor: UInt32) throws {
        writer.write(PictOpcode.compressedQuickTime.rawValue)
        writer.advance(4) // Size will be written later
        let start = writer.bytesWritten
        writer.advance(2 + 36) // version, matrix
        writer.advance(4) // matteSize
        writer.advance(8 + 2 + 8 + 4) // matteRect, transferMode, srcRect, accuracy
        writer.advance(4) // maskSize

        try QTImageDesc.write(rep: imageRep, to: writer, using: compressor)
        let size = UInt32(writer.bytesWritten - start)
        writer.write(size, at: start-4)
    }
}


enum PictOpcode: UInt16 {
    case nop = 0x0000
    case clipRegion = 0x0001
    case textFont = 0x0003
    case textFace = 0x0004
    case textMode = 0x0005
    case penSize = 0x0007
    case penMode = 0x0008
    case penPattern = 0x0009
    case fillPattern = 0x000A
    case origin = 0x000C
    case textSize = 0x000D
    case versionOp = 0x0011
    case rgbFgColor = 0x001A
    case rgbBkCcolor = 0x001B
    case hiliteMode = 0x001C
    case hiliteColor = 0x001D
    case defHilite = 0x001E
    case opColor = 0x001F
    case line = 0x0020
    case lineFrom = 0x0021
    case shortLine = 0x0022
    case shortLineFrom = 0x0023
    case longText = 0x0028
    case dhText = 0x0029
    case dvText = 0x002A
    case dhdvText = 0x002B
    case fontName = 0x002C
    case lineJustify = 0x002D
    case glyphState = 0x002E
    case frameRect = 0x0030
    case paintRect = 0x0031
    case eraseRect = 0x0032
    case invertRect = 0x0033
    case fillRect = 0x0034
    case frameSameRect = 0x0038
    case paintSameRect = 0x0039
    case eraseSameRect = 0x003A
    case invertSameRect = 0x003B
    case fillSameRect = 0x003C
    case bitsRect = 0x0090
    case bitsRegion = 0x0091
    case packBitsRect = 0x0098
    case packBitsRegion = 0x0099
    case directBitsRect = 0x009A
    case directBitsRegion = 0x009B
    case frameRegion = 0x0080
    case paintRegion = 0x0081
    case eraseRegion = 0x0082
    case invertRegion = 0x0083
    case fillRegion = 0x0084
    case shortComment = 0x00A0
    case longComment = 0x00A1
    case opEndPicture = 0x00FF
    case version = 0x02FF
    case headerOp = 0x0C00
    case compressedQuickTime = 0x8200
    case uncompressedQuickTime = 0x8201

    static func read2(_ reader: BinaryDataReader) throws -> Self {
        if reader.bytesRead % 2 == 1 {
            try reader.advance(1)
        }
        guard let op = Self.init(rawValue: try reader.read()) else {
            throw ImageReaderError.unsupported
        }
        return op
    }

    static func read1(_ reader: BinaryDataReader) throws -> Self {
        guard let op = Self.init(rawValue: UInt16(try reader.read() as UInt8)) else {
            throw ImageReaderError.unsupported
        }
        return op
    }
}
