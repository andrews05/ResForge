import AppKit
import RFSupport

class GalaxyView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: GalaxyWindowController!
    private let zoomLevels: [Double] = [8/19, 9/16, 3/4, 1, 4/3, 16/9, 19/8]
    private var transform = AffineTransform()
    private var zoomLevel = 4 {
        didSet {
            if zoomLevel != oldValue {
                transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
                transform.scale(zoomLevels[zoomLevel])
                self.transformSubviews()
            }
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override var subviews: [NSView] {
        didSet {
            self.transformSubviews()
            self.restackSystems()
        }
    }

    override func awakeFromNib() {
        wantsLayer = true
        transform.translate(x: frame.midX, y: frame.midY)
        transform.scale(zoomLevels[zoomLevel])
    }

    private func transformSubviews() {
        for view in controller.systemViews.values {
            view.showName = zoomLevel >= 3
            view.point = transform.transform(view.position)
        }
        needsDisplay = true
    }

    func restackSystems() {
        // Keep track of occupied locations - only the first system at a given point will be displayed
        var topViews: [NSPoint: SystemView] = [:]
        for view in controller.systemViews.values {
            view.highlightCount = 1
            if let topView = topViews[view.point] {
                if !view.isHighlighted {
                    view.isHidden = true
                } else if !topView.isHighlighted {
                    // The current top view is not part of the selection, swap it with this one
                    topView.isHidden = true
                    topViews[view.point] = view
                    view.isHidden = false
                } else if topView != view {
                    topView.highlightCount += 1
                    view.isHidden = true
                }
            } else {
                // No current top view, set it to this one
                topViews[view.point] = view
                view.isHidden = false
            }
        }
    }

    // MARK: - Drawing

    override var needsDisplay: Bool {
        get { layer?.needsDisplay() ?? false }
        set { layer?.setNeedsDisplay() }
    }

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.contentsScale = window?.backingScaleFactor ?? 1
        layer.backgroundColor = .black
        layer.delegate = self
        return layer
    }

    nonisolated func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        return true
    }

    func draw(_ layer: CALayer, in ctx: CGContext) {
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

        // Center lines
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).setFill()
        NSRect(x: frame.midX, y: 0, width: 1, height: frame.height).frame()
        NSRect(x: 0, y: frame.midY, width: frame.height, height: 1).frame()

        // Nebulae
        let font = NSFont.systemFont(ofSize: 11)
        for (id, nebu) in controller.nebulae {
            let rect = transform.transform(nebu.area)
            if let image = controller.nebImages[id] {
                image.draw(in: rect)
            } else {
                NSColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1).setFill()
                rect.fill()
                let textRect = NSRect(x: rect.origin.x + 4, y: rect.origin.y + 12, width: 0, height: 0)
                nebu.name.draw(with: textRect, attributes: [.foregroundColor: NSColor.lightGray, .font: font])
            }
        }

        // Hyperlinks
        let points = controller.systemViews.mapValues(\.point)
        NSColor.darkGray.setStroke()
        let path = NSBezierPath()
        for (fromID, system) in controller.systemViews {
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
    }

    // MARK: - Event handling

    @IBAction func zoomIn(_ sender: Any) {
        zoomLevel = min(zoomLevel+1, 6)
    }

    @IBAction func zoomOut(_ sender: Any) {
        zoomLevel = max(zoomLevel-1, 0)
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

    override func mouseDown(with event: NSEvent) {
        // Deselect all if not holding shift or command and not dragging
        let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        if !toggle,
           let e = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]),
           e.type == .leftMouseUp {
            controller.systemTable.deselectAll(self)
        }
    }

    func mouseDown(system: SystemView, with event: NSEvent) {
        let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        guard toggle || !system.isHighlighted else {
            return
        }
        let state = toggle ? !system.isHighlighted : true
        for view in controller.systemViews.values {
            // Select/deselect all enabled systems at the same point
            if view.isEnabled && view.point == system.point {
                view.isHighlighted = state
            } else if !toggle {
                view.isHighlighted = false
            }
        }
        self.restackSystems()
        controller.syncSelectionFromView(clicked: system)
    }

    override func keyDown(with event: NSEvent) {
        controller.systemTable.keyDown(with: event)
    }

    override func selectAll(_ sender: Any?) {
        controller.systemTable.selectAll(self)
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
