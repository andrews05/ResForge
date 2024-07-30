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
            return multiRep(data.dropFirst(2), width: 8, height: 8, count: count)
        case "SICN":
            let count = data.count / 32
            return multiRep(data, width: 16, height: 16, count: count)
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

    private static func multiRep(_ data: Data, width: Int, height: Int, count: Int) -> NSBitmapImageRep? {
        // Construct the base rep with all the icons stacked vertically
        guard let baseRep = monoRep(data, width: width, height: height * count) else {
            return nil
        }

        // Determine grid size and create output rep
        let maxColumns = max(64 / width, 4)
        let gridX = min(count, maxColumns)
        let gridY = (count + maxColumns - 1) / maxColumns
        let rep = ImageFormat.rgbaRep(width: width * gridX, height: height * gridY)

        // Redraw each icon to the output rep
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        var srcRect = NSRect(x: 0, y: baseRep.pixelsHigh - height, width: width, height: height)
        var destRect = NSRect(x: 0, y: rep.pixelsHigh - height, width: width, height: height)
        for _ in 0..<count {
            baseRep.draw(in: destRect, from: srcRect, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
            srcRect.origin.y -= srcRect.height
            if Int(destRect.maxX) == rep.pixelsWide {
                destRect.origin.x = 0
                destRect.origin.y -= destRect.height
            } else {
                destRect.origin.x += destRect.width
            }
        }
        return rep
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
