import Cocoa
import RFSupport

class DialogEditor: PreviewProvider {
    static var supportedTypes = ["DITL"]

    static func image(for resource: RFSupport.Resource) -> NSImage? {
        let reader = BinaryDataReader(resource.data)
        var items: [DialogItem] = []
        do {
            let count = Int(try reader.read() as Int16) + 1
            for _ in 0..<count {
                items.append(try DialogItem(reader: reader))
            }
        } catch {}

        guard !items.isEmpty else {
            return nil
        }

        let maxX = items.map(\.right).max()!
        let maxY = items.map(\.bottom).max()!
        let image = NSImage(size: NSSize(width: Int(maxX), height: Int(maxY)))

        image.lockFocusFlipped(true)
        NSColor.gray.setFill()
        for item in items {
            item.rect.fill()
        }
        image.unlockFocus()

        return image
    }
}

struct DialogItem {
    let top: Int16
    let left: Int16
    let bottom: Int16
    let right: Int16

    init(reader: BinaryDataReader) throws {
        try reader.advance(4)

        top = try reader.read()
        left = try reader.read()
        bottom = try reader.read()
        right = try reader.read()

        try reader.advance(1)
        _ = try reader.readPString()
        if reader.bytesRead % 2 == 1 {
            try reader.advance(1)
        }
    }

    var rect: NSRect {
        NSRect(x: Int(left), y: Int(top), width: Int(right)-Int(left), height: Int(bottom)-Int(top))
    }
}
