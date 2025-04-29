import AppKit

enum ImageFormat: CustomStringConvertible {
    case unknown
    case monochrome
    case color(Int)
    case quickTime(UInt32, Int)
    case custom(String)

    var description: String {
        switch self {
        case .unknown:
            return ""
        case .monochrome:
            return "Monochrome"
        case let .color(depth):
            if depth <= 8 {
                return "\(depth)-bit Indexed"
            }
            return "\(depth)-bit RGB"
        case let .quickTime(compressor, depth):
            let fourCC = compressor.fourCharString.trimmingCharacters(in: .whitespaces).uppercased()
            return "\(depth)-bit \(fourCC)"
        case let .custom(description):
            return description
        }
    }
}

extension ImageFormat {
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

    /// Ensure 32-bit RGBA.
    static func normalize(_ rep: NSBitmapImageRep) -> NSBitmapImageRep {
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

    @discardableResult static func removeTransparency(_ rep: NSBitmapImageRep) -> ImageFormat {
        if rep.hasAlpha {
            rep.hasAlpha = false
            // Access the bitmap data to make sure it updates correctly
            _ = rep.bitmapData
        }
        return .color(24)
    }

    @discardableResult static func reduceToMono(_ rep: inout NSBitmapImageRep) -> ImageFormat {
        // Reduce to monochrome by converting to gif with a black and white color table
        let monoTable = Data([0, 0, 0, 0xFF, 0xFF, 0xFF])
        let data = rep.representation(using: .gif, properties: [.ditherTransparency: false, .rgbColorTable: monoTable])!
        rep = NSBitmapImageRep(data: data)!
        return .monochrome
    }

    @discardableResult static func reduceTo256Colors(_ rep: inout NSBitmapImageRep) -> ImageFormat {
        // Reduce to 8-bit colour by converting to gif
        let data = rep.representation(using: .gif, properties: [.ditherTransparency: false])!
        rep = NSBitmapImageRep(data: data)!
        // The byte at offset 10 contains information about the global color table. Lowest 3 bits represent the size.
        let depth = (data[10] & 0x07) + 1
        let count = 1 << depth
        // Apple's encoder seems to add extra black at the end which can cause the depth to be higher than necessary.
        // Read the color table at offset 13, trim black entries from the end, and work out the actual depth required
        // based on the remaining count.
        // (It will also always include black and white which may be unused, but we can't easily determine this.)
        let offset = 13
        let gct = data[offset..<(offset + count * 3)]
        let nonZeroLength = (gct.lastIndex { $0 != 0 } ?? offset + 3) - offset
        let trimmedCount = (nonZeroLength + 2) / 3
        let actualDepth = switch trimmedCount {
        case ...2: 1
        case ...4: 2
        case ...16: 4
        default: 8
        }
        return .color(actualDepth)
    }

    @discardableResult static func rgb555Dither(_ rep: NSBitmapImageRep) -> ImageFormat {
        // QuickDraw dithering algorithm.
        // Half the error is diffused right on even rows, left on odd rows. The remainder is diffused down.
        let rowBytes = rep.bytesPerRow // This is a computed property, only access it once.
        var bitmap = rep.bitmapData!
        for y in 0..<rep.pixelsHigh {
            let even = y % 2 == 0
            let row = even ? stride(from: 0, through: rowBytes-1, by: 1) : stride(from: rowBytes-1, through: 0, by: -1)
            for x in row where x % 4 != 3 {
                // To perfectly replicate QuickDraw we would simply take the error as the lower 3 bits of the value.
                // This is not entirely accurate though and has the side-effect that repeat dithers will degrade the image.
                // To fix this we get the difference between original value and the 5-to-8 restored value.
                let newVal = (bitmap[x] & 0xF8) | (bitmap[x] / 0x20)
                let error = Int(bitmap[x]) - Int(newVal)
                if error != 0 {
                    bitmap[x] = newVal
                    if even && x+4 < rowBytes {
                        bitmap[x+4] = UInt8(clamping: Int(bitmap[x+4]) + error / 2)
                    } else if !even && x > 0 {
                        bitmap[x-4] = UInt8(clamping: Int(bitmap[x-4]) + error / 2)
                    }
                    if y+1 < rep.pixelsHigh {
                        bitmap[x+rowBytes] = UInt8(clamping: Int(bitmap[x+rowBytes]) + (error+1) / 2)
                    }
                }
            }
            bitmap += rowBytes
        }
        return .color(16)
    }
}

enum ImageReaderError: Error {
    case invalid
    case unsupported
}

enum ImageWriterError: LocalizedError {
    case unsupported
    case tooBig
    case tooManyColors
    var errorDescription: String? {
        switch self {
        case .unsupported:
            NSLocalizedString("The image cannot be encoded in this format.", comment: "")
        case .tooBig:
            NSLocalizedString("The image is too big to be encoded in this format.", comment: "")
        case .tooManyColors:
            NSLocalizedString("The image has too many colors to be encoded in this format.", comment: "")
        }
    }
}
