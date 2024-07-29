import AppKit
import RFSupport

class Icons {
    static func rep(_ data: Data, for type: ResourceType) -> NSBitmapImageRep? {
        switch type.code {
        case "ICON":
            return monoRep(data, width: 32, height: 32)
        case "ICN#":
            return monoRep(data, width: 32, height: 32, hasMask: true)
        case "ics#", "kcs#", "CURS":
            return monoRep(data, width: 16, height: 16, hasMask: true)
        case "icm#":
            return monoRep(data, width: 16, height: 12, hasMask: true)
        case "icl4":
            return colorRep(data, width: 32, height: 32, depth: 4)
        case "ics4", "kcs4":
            return colorRep(data, width: 16, height: 16, depth: 4)
        case "icm4":
            return colorRep(data, width: 16, height: 12, depth: 4)
        case "icl8":
            return colorRep(data, width: 32, height: 32, depth: 8)
        case "ics8", "kcs8":
            return colorRep(data, width: 16, height: 16, depth: 8)
        case "icm8":
            return colorRep(data, width: 16, height: 12, depth: 8)
        case "PAT ":
            return monoRep(data, width: 8, height: 8)
        case "PAT#":
            guard data.count > 2 else {
                return nil
            }
            let count = Int(data[data.startIndex]) << 8 | Int(data[data.startIndex + 1])
            return monoRep(data.dropFirst(2), width: 8, height: 8 * count)
        case "SICN":
            let count = data.count / 32
            return monoRep(data, width: 16, height: 16 * count)
        default:
            return nil
        }
    }

    static func applyMask(for resource: Resource, to rep: NSBitmapImageRep, manager: RFEditorManager) {
        let maskType: String? = switch resource.typeCode {
        case "icl4", "icl8":
            "ICN#"
        case "icm4", "icm8":
            "icm#"
        case "ics4", "ics8":
            "ics#"
        case "kcs4", "kcs8":
            "kcs#"
        default:
            nil
        }
        if let maskType,
           let mono = manager.findResource(type: ResourceType(maskType), id: resource.id, currentDocumentOnly: true),
           let monoRep = Self.rep(mono.data, for: mono.type) {
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            let rect = NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
            monoRep.draw(in: rect, from: .zero, operation: .destinationIn, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    private static func monoRep(_ data: Data, width: Int, height: Int, hasMask: Bool = false) -> NSBitmapImageRep? {
        let bytesPerRow = width / 8
        let planeLength = bytesPerRow * height
        let planeCount = hasMask ? 2 : 1
        guard planeLength > 0,
              data.count >= planeLength * planeCount
        else {
            return nil
        }

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: width,
                                   pixelsHigh: height,
                                   bitsPerSample: 1,
                                   samplesPerPixel: planeCount,
                                   hasAlpha: hasMask,
                                   isPlanar: true,
                                   colorSpaceName: .deviceWhite,
                                   bytesPerRow: bytesPerRow,
                                   bitsPerPixel: 1)!
        let bitmap = rep.bitmapData!
        data.copyBytes(to: bitmap, count: planeLength * planeCount)
        // Invert bitmap plane
        for i in 0..<planeLength {
            bitmap[i] ^= 0xFF
        }
        return rep
    }

    private static func colorRep(_ data: Data, width: Int, height: Int, depth: Int) -> NSBitmapImageRep? {
        guard depth == 4 || depth == 8,
              data.count == width * height * depth / 8
        else {
            return nil
        }

        let rep = ImageFormat.rgbaRep(width: width, height: height)
        var bitmap = rep.bitmapData!
        if depth == 4 {
            let palette = ColorTable.system4
            for byte in data {
                palette[Int(byte >> 4)].draw(to: &bitmap)
                palette[Int(byte & 0x0F)].draw(to: &bitmap)
            }
        } else if depth == 8 {
            let palette = ColorTable.system8
            for byte in data {
                palette[Int(byte)].draw(to: &bitmap)
            }
        }
        return rep
    }
}
