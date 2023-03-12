import Cocoa
import RFSupport

class GalaxyView: NSView {
    @IBOutlet weak var controller: GalaxyWindowController!
    let zoomLevels: [CGFloat] = [8/19, 9/16, 3/4, 1, 4/3, 16/9, 19/8]
    var transform = AffineTransform()
    var zoomLevel = 4 {
        didSet {
            if zoomLevel != oldValue {
                transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
                transform.scale(zoomLevels[zoomLevel])
                needsDisplay = true
            }
        }
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func awakeFromNib() {
        transform.translate(x: frame.midX, y: frame.midY)
        transform.scale(zoomLevels[zoomLevel])
    }

    override func updateLayer() {
        let points = controller.systems.mapValues {
            transform.transform($0.pos)
        }
        var pointNames: [NSPoint: [String]] = [:]
        for (id, point) in points {
            if let system = controller.systems[id] {
                pointNames[point, default: []].append(system.name)
            }
        }

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

        // Systems - show in purple if multiple systems at one point
        NSColor.black.setFill()
        for (point, names) in pointNames {
            let rect = NSRect(x: point.x-4, y: point.y-4, width: 8, height: 8)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
            (names.count == 1 ? NSColor.blue : NSColor.purple).setStroke()
            path.stroke()
        }

        // Highlight the target system
        if let point = points[controller.targetID] {
            NSColor.cyan.setFill()
            let rect = NSRect(x: point.x-2, y: point.y-2, width: 4, height: 4)
            NSBezierPath(ovalIn: rect).fill()
        }

        // System names - show first name only
        if zoomLevel >= 3 {
            for (point, names) in pointNames {
                let rect = NSRect(x: point.x.rounded()+8, y: point.y.rounded()+4, width: 0, height: 0)
                names[0].draw(with: rect, attributes: [.foregroundColor: NSColor.white, .font: font])
            }
        }

        image.unlockFocus()
        layer?.contents = image
    }

    // Drag to scroll
    override func mouseDragged(with event: NSEvent) {
        if let clipView = superview as? NSClipView {
            var origin = clipView.bounds.origin
            origin.x -= event.deltaX
            origin.y += event.deltaY
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
