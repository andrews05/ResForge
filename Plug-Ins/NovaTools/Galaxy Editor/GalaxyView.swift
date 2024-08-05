import AppKit
import RFSupport

class GalaxyView: NSView {
    @IBOutlet weak var controller: GalaxyWindowController!
    private let zoomLevels: [CGFloat] = [8/19, 9/16, 3/4, 1, 4/3, 16/9, 19/8]
    private var transform = AffineTransform()
    private var zoomLevel = 4 {
        didSet {
            if zoomLevel != oldValue {
                transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
                transform.scale(zoomLevels[zoomLevel])
                self.updateSubviews()
            }
        }
    }

    override var isFlipped: Bool {
        true
    }
    override var wantsUpdateLayer: Bool {
        true
    }
    override var subviews: [NSView] {
        didSet {
            self.updateSubviews()
        }
    }

    override func awakeFromNib() {
        transform.translate(x: frame.midX, y: frame.midY)
        transform.scale(zoomLevels[zoomLevel])
    }

    private func updateSubviews() {
        var points: [NSPoint: SystemView] = [:]
        for system in subviews as! [SystemView] {
            system.overlaps = false
            system.update(transform, showName: zoomLevel >= 3)
            if let existing = points[system.point] {
                existing.overlaps = true
                // Don't draw this system but still allow it to respond to clicks
                system.alphaValue = 0
            } else {
                points[system.point] = system
                system.alphaValue = 1
            }
        }
        needsDisplay = true
    }

    override func updateLayer() {
        let image = NSImage(size: frame.size)
        image.lockFocusFlipped(true)

        // Center lines
        NSColor.black.setFill()
        frame.fill()
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).setFill()
        NSRect(x: frame.midX, y: 0, width: 1, height: frame.height).frame()
        NSRect(x: 0, y: frame.midY, width: frame.height, height: 1).frame()

        // Nebulae
        let font = NSFont.systemFont(ofSize: 11)
        for (id, nebu) in controller.nebulae {
            var rect = transform.transform(nebu.area)
            if let image = controller.nebImages[id] {
                image.draw(in: rect)
            } else {
                NSColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1).setFill()
                rect.fill()
                rect.origin.x += 4
                rect.origin.y += 12
                nebu.name.draw(with: rect, attributes: [.foregroundColor: NSColor.lightGray, .font: font])
            }
        }

        // Hyperlinks
        let points = controller.systems.mapValues(\.point)
        NSColor.darkGray.setStroke()
        let path = NSBezierPath()
        for (fromID, system) in controller.systems {
            guard let from = points[fromID] else {
                continue
            }
            for id in system.links {
                guard let to = points[id] else {
                    continue
                }
                path.move(to: from)
                path.line(to: to)
            }
        }
        path.lineWidth = 1.2
        path.stroke()

        image.unlockFocus()
        layer?.contents = image
    }

    // Drag to scroll
    override func mouseDragged(with event: NSEvent) {
        if let clipView = superview as? NSClipView {
            var origin = clipView.bounds.origin
            origin.x -= event.deltaX
            origin.y -= event.deltaY
            self.scroll(origin)
        }
    }

    @IBAction func zoomIn(_ sender: Any) {
        zoomLevel = min(zoomLevel+1, 6)
    }

    @IBAction func zoomOut(_ sender: Any) {
        zoomLevel = max(zoomLevel-1, 0)
    }
}

extension AffineTransform {
    func transform(_ rect: NSRect) -> NSRect {
        NSRect(origin: transform(rect.origin), size: transform(rect.size))
    }
}

extension NSPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
}
