import AppKit
import RFSupport

class SystemView: NSView {
    private(set) var resource: Resource
    private(set) var point: NSPoint
    private(set) var links: [Int]
    private var position: NSPoint
    private var showName = true
    private var attributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 11)]
    }
    var isEnabled: Bool
    var overlaps = false

    override var isFlipped: Bool {
        true
    }

    init?(_ system: Resource, isEnabled: Bool) {
        let reader = BinaryDataReader(system.data)
        do {
            position = NSPoint(
                x: CGFloat(try reader.read() as Int16),
                y: CGFloat(try reader.read() as Int16)
            )
            links = try (0..<16).map { _ in
                Int(try reader.read() as Int16)
            }
        } catch {
            return nil
        }
        resource = system
        point = position
        self.isEnabled = isEnabled
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard dirtyRect.minX..<dirtyRect.maxX ~= frame.width || dirtyRect.minY..<dirtyRect.maxY ~= frame.height else {
            return
        }

        NSColor.black.setFill()
        if !isEnabled {
            NSColor.gray.setStroke()
        } else if overlaps {
            NSColor.purple.setStroke()
        } else {
            NSColor.blue.setStroke()
        }
        let circle = NSRect(x: 2, y: 2, width: 8, height: 8)
        let path = NSBezierPath(ovalIn: circle)
        path.fill()
        path.stroke()

        if showName {
            let rect = NSRect(x: 14, y: 10, width: 0, height: 0)
            resource.name.draw(with: rect, attributes: attributes)
        }
    }

    func update(_ tranform: AffineTransform, showName: Bool) {
        self.showName = showName
        point = tranform.transform(position)
        frame.origin.x = point.x - 6
        frame.origin.y = point.y - 6
        frame.size.height = 12
        frame.size.width = 12
        if showName {
            let nameBounds = resource.name.boundingRect(with: NSSize(width: 1000, height: 1000), attributes: attributes)
            frame.size.width += 2 + nameBounds.width + 2
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        print(resource.name)
        super.mouseDown(with: event)
    }
}
