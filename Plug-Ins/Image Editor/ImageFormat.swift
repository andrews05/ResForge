import AppKit

enum ImageFormat: CustomStringConvertible {
    case unknown
    case monochrome
    case color(Int)
    case quickTime(UInt32, Int)

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

    static func removeTransparency(_ rep: inout NSBitmapImageRep) {
        if rep.hasAlpha {
            rep.hasAlpha = false
            // Access the bitmap data to make sure it updates correctly
            _ = rep.bitmapData
        }
    }

    static func reduceTo256Colors(_ rep: inout NSBitmapImageRep) {
        // Reduce to 8-bit colour by converting to gif
        let data = rep.representation(using: .gif, properties: [.ditherTransparency: false])!
        rep = NSBitmapImageRep(data: data)!
    }
}

enum ImageReaderError: Error {
    case invalid
    case unsupported
}

enum ImageWriterError: LocalizedError {
    case tooBig
    case tooManyColors
    var errorDescription: String? {
        switch self {
        case .tooBig:
            NSLocalizedString("The image is too big to be encoded in this format.", comment: "")
        case .tooManyColors:
            NSLocalizedString("The image has too many colors to be encoded in this format.", comment: "")
        }
    }
}
