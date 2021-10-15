import Cocoa
import RFSupport

class GalaxyView: NSView {
    @IBOutlet weak var controller: GalaxyWindowController!
    var transform = AffineTransform()
    var points: [Int: NSPoint] = [:]
    var pointMap: [NSPoint: [Resource]] = [:]
    
    override var isFlipped: Bool {
        true
    }
    
    override func awakeFromNib() {
        transform.translate(x: frame.midX, y: frame.midY)
        transform.scale(x: 1.3333, y: 1.3333)
        points = controller.points.mapValues(transform.transform)
        for (id, point) in points {
            if let system = controller.systems[id] {
                pointMap[point, default: []].append(system)
            }
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        frame.fill()
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).setFill()
        NSRect(x: frame.midX, y: 0, width: 1, height: frame.height).frame()
        NSRect(x: 0, y: frame.midY, width: frame.height, height: 1).frame()
        NSColor.darkGray.setStroke()
        for link in controller.links {
            guard let from = points[link.0], let to = points[link.1] else {
                continue
            }
            NSBezierPath.strokeLine(from: from, to: to)
        }
        NSColor.black.setFill()
        for (point, systems) in pointMap {
            let rect = NSRect(x: point.x-4, y: point.y-4, width: 8, height: 8)
            let path = NSBezierPath(ovalIn: rect)
            path.fill()
            (systems.count == 1 ? NSColor.blue : NSColor.purple).setStroke()
            path.stroke()
        }
//        NSGraphicsContext.current?.shouldAntialias = false
//        let font = NSFont(name: "Geneva", size: 10)
        let font = NSFont.systemFont(ofSize: 11)
        for (point, systems) in pointMap {
            if let name = systems.first?.name {
                let rect = NSRect(x: point.x.rounded()+8, y: point.y.rounded()+4, width: 0, height: 0)
                name.draw(with: rect, attributes: [.foregroundColor: NSColor.white, .font: font])
            }
        }
    }
}
