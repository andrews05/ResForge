import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=727

struct Picture {
    static let version1: UInt16 = 0x1101 // 1-byte versionOp + version number
    static let version2: Int16 = -1
    static let extendedVersion2: Int16 = -2
    private var v1: Bool
    private var frame: QDRect
    private var clipRect: QDRect
    private var origin: QDPoint

    var imageRep: NSBitmapImageRep
    var format: ImageFormat = .unknown
}

extension Picture {
    init(_ reader: BinaryDataReader, _ readOps: Bool = true) throws {
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
            if headerVersion == Self.version2 {
                try reader.advance(2 + 16 + 4) // ??, fixed-point bounding box, reserved
            } else if headerVersion == Self.extendedVersion2 {
                try reader.advance(2 + 4 + 4) // reserved, hRes, vRes
                // Set the frame to the source rect. This isn't strictly correct but it allows us
                // to decode some images which would otherwise fail due to mismatched frame sizes
                // (QuickDraw would normally scale such images to fit the frame).
                frame = try QDRect(reader)
                try reader.advance(4) // reserved
            } else {
                throw ImageReaderError.invalid
            }
        }

        guard frame.isValid else {
            throw ImageReaderError.invalid
        }

        origin = frame.origin
        clipRect = frame
        imageRep = ImageFormat.rgbaRep(width: frame.width, height: frame.height)
        if readOps {
            try self.readOps(reader)
        }
    }

    static func rep(_ data: Data, format: inout ImageFormat) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard var pict = try? Self(reader, false) else {
            return nil
        }
        do {
            try pict.readOps(reader)
            format = pict.format
            return pict.imageRep
        } catch {
            // We may still be able to show the format even if decoding failed
            format = pict.format
            return nil
        }
    }

    private mutating func readOps(_ reader: BinaryDataReader) throws {
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
            case .nop, .hiliteMode, .defHilite,
                    .frameSameRect, .paintSameRect, .eraseSameRect, .invertSameRect, .fillSameRect:
                continue
            case .penMode, .shortLineFrom, .shortComment:
                try reader.advance(2)
            case .penSize, .lineFrom:
                try reader.advance(4)
            case .shortLine, .rgbFgColor, .rgbBkCcolor, .hiliteColor, .opColor:
                try reader.advance(6)
            case .penPattern, .fillPattern, .line,
                    .frameRect, .paintRect, .eraseRect, .invertRect, .fillRect:
                try reader.advance(8)
            case .frameRegion, .paintRegion, .eraseRegion, .invertRegion, .fillRegion:
                try self.skipRegion(reader)
            case .longComment:
                try self.skipLongComment(reader)
            case .compressedQuickTime:
                try self.readQuickTime(reader)
                // A successful QuickTime decode will replace the imageRep and we should stop processing.
                return
            case .uncompressedQuickTime:
                // Uncompressed QuickTime contains a matte which we can skip over. Actual image data should follow.
                let length = Int(try reader.read() as UInt32)
                try reader.advance(length)
            default:
                throw ImageReaderError.unsupported
            }
        }

        // If we reached the end and have nothing to show for it then we should fail
        if case .unknown = format {
            throw ImageReaderError.unsupported
        }
    }

    private mutating func readIndirectBitsRect(_ reader: BinaryDataReader, packed: Bool, withMaskRegion: Bool) throws {
        let pixMap = try PixelMap(reader, skipBaseAddr: true)
        format = pixMap.format
        let colorTable = if pixMap.isPixmap {
            try ColorTable.read(reader)
        } else {
            ColorTable.system1
        }

        let (srcRect, destRect) = try self.readSrcAndDestRects(reader)

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

        try pixMap.draw(pixelData, colorTable: colorTable, to: imageRep, in: destRect, from: srcRect)
    }

    private mutating func readDirectBits(_ reader: BinaryDataReader, withMaskRegion: Bool) throws {
        let pixMap = try PixelMap(reader)
        format = pixMap.format

        let (srcRect, destRect) = try self.readSrcAndDestRects(reader)

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

        try pixMap.draw(pixelData, to: imageRep, in: destRect, from: srcRect)
    }

    private func readSrcAndDestRects(_ reader: BinaryDataReader) throws -> (srcRect: QDRect, destRect: QDRect) {
        var srcRect = try QDRect(reader)
        var destRect = try QDRect(reader)
        // Source rect may be bigger than dest - clip if necessary (smaller would be invalid)
        if srcRect.width > destRect.width {
            srcRect.right = srcRect.left + destRect.width
        }
        if srcRect.height > destRect.height {
            srcRect.bottom = srcRect.top + destRect.height
        }
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

    private mutating func readClipRegion(_ reader: BinaryDataReader) throws {
        let length = Int(try reader.read() as UInt16)
        clipRect = try QDRect(reader)
        guard clipRect.isValid else {
            throw ImageReaderError.invalid
        }
        try reader.advance(length - 10)
    }

    private mutating func readOrigin(_ reader: BinaryDataReader) throws {
        let delta = try QDPoint(reader)
        origin.x += delta.x
        origin.y += delta.y
    }

    private func skipRegion(_ reader: BinaryDataReader) throws {
        let length = Int(try reader.read() as UInt16)
        try reader.advance(length - 2)
    }

    private func skipLongComment(_ reader: BinaryDataReader) throws {
        try reader.advance(2) // kind
        let length = Int(try reader.read() as UInt16)
        try reader.advance(length)
    }

    private mutating func readQuickTime(_ reader: BinaryDataReader) throws {
        // https://vintageapple.org/inside_r/pdf/QuickTime_1993.pdf#484
        let size = Int(try reader.read() as UInt32)

        // Construct a new reader constrained to the specified size
        let reader = BinaryDataReader(try reader.readData(length: size))
        try reader.advance(2 + 36) // version, matrix
        let matteSize = Int(try reader.read() as UInt32)
        try reader.advance(8 + 2 + 8 + 4) // matteRect, transferMode, srcRect, accuracy
        let maskSize = Int(try reader.read() as UInt32)
        if matteSize > 0 {
            try reader.advance(matteSize)
        }
        if maskSize > 0 {
            try reader.advance(maskSize)
        }

        let imageDesc = try QTImageDesc(reader)
        format = .quickTime(imageDesc.compressor, imageDesc.resolvedDepth)
        imageRep = try imageDesc.readImage(reader)
    }
}

// MARK: Writer

extension Picture {
    init(imageRep: NSBitmapImageRep) throws {
        self.imageRep = ImageFormat.normalize(imageRep)
        v1 = false
        frame = try QDRect(for: imageRep)
        clipRect = frame
        origin = frame.origin
    }

    static func data(from rep: NSBitmapImageRep, format: inout ImageFormat) throws -> Data {
        var pict = try Self(imageRep: rep)
        let writer = BinaryDataWriter()
        try pict.write(writer, format: format)
        format = pict.format
        return writer.data
    }

    mutating func write(_ writer: BinaryDataWriter, format: ImageFormat) throws {
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

    private mutating func writeIndirectBits(_ writer: BinaryDataWriter, mono: Bool = false) throws {
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
    case penSize = 0x0007
    case penMode = 0x0008
    case penPattern = 0x0009
    case fillPattern = 0x000A
    case origin = 0x000C
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
