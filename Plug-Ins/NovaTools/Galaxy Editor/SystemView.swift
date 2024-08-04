import AppKit
import RFSupport

class SystemView: NSView {
    let resource: Resource
    let isEnabled: Bool
    private(set) var position = NSPoint.zero
    private(set) var links: [Int] = []
    private var attributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 11)]
    }
    var showName = true
    var point = NSPoint.zero {
        didSet {
            self.updateFrame()
        }
    }
    var isHighlighted = false {
        didSet {
            if oldValue != isHighlighted {
                needsDisplay = true
            }
        }
    }
    var highlightCount = 1 {
        didSet {
            if oldValue != highlightCount {
                needsDisplay = true
            }
        }
    }

    init?(_ system: Resource, isEnabled: Bool) {
        resource = system
        self.isEnabled = isEnabled
        super.init(frame: .zero)
        do {
            try self.read()
        } catch {
            return nil
        }
    }

    func read() throws {
        let reader = BinaryDataReader(resource.data)
        position.x = Double(try reader.read() as Int16)
        position.y = Double(try reader.read() as Int16)
        links = try (0..<16).map { _ in
            Int(try reader.read() as Int16)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateFrame() {
        frame.origin.x = point.x - 6
        frame.origin.y = point.y - 6
        frame.size.height = 12
        frame.size.width = 12
        if showName {
            let nameBounds = resource.name.boundingRect(with: .zero, attributes: attributes)
            frame.size.width += 2 + nameBounds.width + 2
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard dirtyRect.intersects(bounds) else {
            return
        }

        if isHighlighted {
            // Highlight background
            NSColor.selectedContentBackgroundColor.setFill()
            var bgRect = bounds
            if showName {
                bgRect.size.width += 2
            }
            NSBezierPath(roundedRect: bgRect, xRadius: 6, yRadius: 6).fill()

            // Black circle
            NSColor.black.setFill()
            let circle = NSRect(x: 1, y: 1, width: 10, height: 10)
            NSBezierPath(ovalIn: circle).fill()

            // Count of selected systems at this point
            let countRect = NSRect(x: 3.5, y: 3, width: 0, height: 0)
            "\(highlightCount)".draw(with: countRect, attributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 9)])
        } else {
            NSColor.black.setFill()
            if isEnabled {
                NSColor.blue.setStroke()
            } else {
                NSColor.gray.setStroke()
            }
            let circle = NSRect(x: 2, y: 2, width: 8, height: 8)
            let path = NSBezierPath(ovalIn: circle)
            path.fill()
            path.stroke()
        }

        if showName {
            let rect = NSRect(x: 14, y: 2.5, width: 0, height: 0)
            resource.name.draw(with: rect, attributes: attributes)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if isEnabled {
            (superview as! GalaxyView).mouseDown(system: self, with: event)
        }
    }
}
