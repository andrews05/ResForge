import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/ImagingWithQuickDraw.pdf#page=727

struct Picture {
    static let version1: UInt16 = 0x1101 // 1-byte versionOp + version number
    static let version2: Int16 = -1
    static let extendedVersion2: Int16 = -2
    private var frame: QDRect
    private var clipRect: QDRect
    private var origin: QDPoint

    var imageRep: NSBitmapImageRep
    var format: UInt32 = 0
}

extension Picture {
    init(_ reader: BinaryDataReader) throws {
        try reader.advance(2) // v1 size
        frame = try QDRect(reader)

        let versionOp = try reader.read() as UInt16
        let v1 = versionOp == Self.version1
        if !v1 {
            guard versionOp == PictOpcode.versionOp.rawValue,
                  try PictOpcode.read2(reader) == .version,
                  try PictOpcode.read2(reader) == .headerOp
            else {
                throw ImageReaderError.invalidData
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
                throw ImageReaderError.invalidData
            }
        }

        origin = frame.origin
        clipRect = frame
        imageRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: frame.width,
                                    pixelsHigh: frame.height,
                                    bitsPerSample: 8,
                                    samplesPerPixel: 4,
                                    hasAlpha: true,
                                    isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bytesPerRow: frame.width * 4,
                                    bitsPerPixel: 0)!

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
            case .uncompressedQuickTime:
                // Uncompressed QuickTime contains a matte which we can skip over. Actual image data should follow.
                let length = Int(try reader.read() as UInt32)
                try reader.advance(length)
            default:
                throw ImageReaderError.unsupported
            }
        }

        // If we reached the end and have nothing to show for it then we should fail
        guard format != 0 else {
            throw ImageReaderError.unsupported
        }
    }

    static func rep(_ data: Data, format: inout UInt32) -> NSBitmapImageRep? {
        let reader = BinaryDataReader(data)
        guard let pict = try? Self(reader) else {
            return nil
        }
        format = pict.format
        return pict.imageRep
    }

    private mutating func readIndirectBitsRect(_ reader: BinaryDataReader, packed: Bool, withMaskRegion: Bool) throws {
        let pixMap = try QDPixMap(reader, skipBaseAddr: true)
        format = UInt32(pixMap.pixelSize)
        let colorTable = if pixMap.isPixmap {
            try ColorTable.read(reader)
        } else {
            ColorTable.monochrome
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
        let pixMap = try QDPixMap(reader)
        // Pixel size is always either 16 or 32 but we want to show 24 if only 3 components are stored
        format = pixMap.pixelSize == 16 ? 16 : UInt32(pixMap.cmpCount * pixMap.cmpSize)

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
        // Align dest rect to the origin
        try destRect.alignTo(origin)
        return (srcRect, destRect)
    }

    private mutating func readClipRegion(_ reader: BinaryDataReader) throws {
        let length = Int(try reader.read() as UInt16)
        clipRect = try QDRect(reader)
        try reader.advance(length - 10)
    }

    private mutating func readOrigin(_ reader: BinaryDataReader) throws {
        origin.x &+= try reader.read()
        origin.y &+= try reader.read()
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
