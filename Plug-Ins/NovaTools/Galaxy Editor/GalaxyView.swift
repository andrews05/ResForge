import Cocoa
import RFSupport

class GalaxyView: NSView {
    @IBOutlet weak var controller: GalaxyWindowController!
    var transform = AffineTransform()
    
    override var wantsUpdateLayer: Bool {
        true
    }
    
    override func awakeFromNib() {
        wantsLayer = true
        transform.translate(x: frame.midX, y: frame.midY)
        transform.scale(x: 1.3333, y: 1.3333)
    }
    
    override func updateLayer() {
        let points = controller.systems.mapValues {
            transform.transform($0.pos)
        }
        var pointMap: [NSPoint: [String]] = [:]
        for (id, point) in points {
            if let system = controller.systems[id] {
                pointMap[point, default: []].append(system.name)
            }
        }
        
        let image = NSImage(size: frame.size)
        image.lockFocusFlipped(true)
        NSColor.black.setFill()
        frame.fill()
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).setFill()
        NSRect(x: frame.midX, y: 0, width: 1, height: frame.height).frame()
        NSRect(x: 0, y: frame.midY, width: frame.height, height: 1).frame()
        
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
        
        NSColor.darkGray.setStroke()
        let path = NSBezierPath()
        for link in controller.links {
            guard let from = points[link.0], let to = points[link.1] else {
                continue
            }
            path.move(to: from)
            path.line(to: to)
        }
        path.lineWidth = 1.2
        path.stroke()
        
        NSColor.black.setFill()
        for (point, systems) in pointMap {
            let rect = NSRect(x: point.x-4, y: point.y-4, width: 8, height: 8)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
            (systems.count == 1 ? NSColor.blue : NSColor.purple).setStroke()
            path.stroke()
        }
        
        // Highlight the target system
        if let point = points[controller.centerID] {
            NSColor.cyan.setFill()
            let rect = NSRect(x: point.x-2, y: point.y-2, width: 4, height: 4)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
        }
        
        for (point, names) in pointMap {
            let rect = NSRect(x: point.x.rounded()+8, y: point.y.rounded()+4, width: 0, height: 0)
            names[0].draw(with: rect, attributes: [.foregroundColor: NSColor.white, .font: font])
        }
        
        image.unlockFocus()
        layer?.contents = image
    }
}

extension AffineTransform {
    func transform(_ rect: NSRect) -> NSRect {
        NSRect(origin: transform(rect.origin), size: transform(rect.size))
    }
}
