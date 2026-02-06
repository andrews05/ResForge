import AppKit
import RFSupport
import CoreImage.CIFilterBuiltins

class NebulaView: ItemView {
    private(set) var rect = NSRect.zero
    private(set) var image: NSImageRep?
    var galaxyView: GalaxyView? {
        (superview as? BackgroundView)?.controller.galaxyView
    }
    override var point: NSPoint {
        get { frame.origin }
        set { frame.origin = newValue }
    }

    override func read() throws {
        let reader = BinaryDataReader(resource.data)
        rect = NSRect(
            x: Double(try reader.read() as Int16),
            y: Double(try reader.read() as Int16),
            width: Double(try reader.read() as Int16),
            height: Double(try reader.read() as Int16)
        )
        // Find the largest available image
        let first = (resource.id - 128) * 7 + 9500
        for id in (first..<first+7).reversed() {
            if let pict = manager.findResource(type: .picture, id: id) {
                pict.preview { img in
                    // Converting to sRGB avoids glitches with the colorspace randomly going wrong at times
                    if let bitmap = img?.representations.first as? NSBitmapImageRep {
                        self.image = bitmap.converting(to: .sRGB, renderingIntent: .default)
                    }
                    self.needsDisplay = true
                }
                break
            }
        }
    }

    override func updateFrame() {
        if let frame = galaxyView?.transform.transform(rect) {
            self.frame = frame
        }
    }

    override func move(to newPos: NSPoint) {
        let curPos = rect.origin
        rect.origin = NSPoint(x: newPos.x.rounded(), y: newPos.y.rounded())
        self.updateFrame()
        self.save()
        undoManager?.registerUndo(withTarget: self) { $0.move(to: curPos) }
    }

    private func save() {
        guard resource.data.count >= 4 * 2 else {
            return
        }
        let writer = BinaryDataWriter()
        writer.data = resource.data
        writer.write(Int16(rect.minX), at: 0)
        writer.write(Int16(rect.minY), at: 2)
        writer.write(Int16(rect.width), at: 4)
        writer.write(Int16(rect.height), at: 6)
        galaxyView?.isSavingItem = true
        resource.data = writer.data
        galaxyView?.isSavingItem = false
        galaxyView?.needsDisplay = true
    }

    override func makeBackingLayer() -> CALayer {
        compositingFilter = CIFilter.screenBlendMode()
        return super.makeBackingLayer()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard dirtyRect.intersects(bounds) else {
            return
        }

        if let image {
            layer?.backgroundColor = nil
            image.draw(in: bounds)
        } else {
            layer?.backgroundColor = isEnabled ? NSColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1).cgColor : NSColor.darkGray.cgColor
            resource.name.draw(in: bounds.insetBy(dx: 4, dy: 2), withAttributes: [.foregroundColor: NSColor.lightGray, .font: NSFont.systemFont(ofSize: 11)])
        }

        layer?.borderColor = NSColor.selectedContentBackgroundColor.cgColor
        layer?.cornerRadius = isHighlighted ? 6 : 0
        layer?.borderWidth = isHighlighted ? 2 : 0
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        if isEnabled {
            galaxyView?.mouseDown(item: self, with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isEnabled {
            galaxyView?.mouseUp(item: self, with: event)
        }
    }
}
