import AppKit
import RFSupport

class SystemMapView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: SystemWindowController!
    private(set) var transform = AffineTransform()
    var isSavingStellar = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func awakeFromNib() {
        self.updateScale()
    }

    func syncViews() {
        self.restackStellars()
        self.transformSubviews()
    }

    private func transformSubviews() {
        for view in subviews {
            (view as? StellarView)?.updateFrame()
        }
    }

    func restackStellars() {
        let views = controller.navDefaults.compactMap(\.view)
        subviews = views
        selectedStellars = views.filter(\.isHighlighted)
        // Keep selected stellars on top
        for view in selectedStellars {
            self.addSubview(view)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Centre line
        let path = NSBezierPath()
        NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 0.4).setStroke()
        path.move(to: NSPoint(x: frame.minX, y: frame.midY - 0.5))
        path.line(to: NSPoint(x: frame.maxX, y: frame.midY - 0.5))
        path.move(to: NSPoint(x: frame.midX - 0.5, y: frame.minY))
        path.line(to: NSPoint(x: frame.midX - 0.5, y: frame.maxY))
        // Default safe jump distance
        let jumpZone = transform.transform(NSRect(x: -1000, y: -1000, width: 2000, height: 2000))
        path.appendOval(in: jumpZone)
        path.stroke()
    }

    // MARK: - Pan and zoom

    private let zoomLevels: [Double] = [1/16, 1/8, 1/4, 8/19, 9/16, 3/4, 1]
    private var zoomLevel = 3 {
        didSet {
            if zoomLevel != oldValue, let enclosingScrollView {
                let documentRect = enclosingScrollView.documentVisibleRect
                let oldPos = NSPoint(x: documentRect.midX / frame.size.width, y: documentRect.midY / frame.size.height)

                self.updateScale()
                self.transformSubviews()

                let scrollOrigin = NSPoint(x: oldPos.x * frame.size.width - documentRect.width / 2, y: oldPos.y * frame.size.height - documentRect.height / 2)
                self.scroll(scrollOrigin)
                enclosingScrollView.flashScrollers()
            }
        }
    }

    private func updateScale() {
        let scaleFactor = zoomLevels[zoomLevel]
        // EVN wraps the player around at ±15000 from the origin, so a stellar could conceivably be placed anywhere within
        // that range
        frame.size = NSSize(width: Int(30000 * scaleFactor), height: Int(30000 * scaleFactor))
        needsDisplay = true

        transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
        transform.scale(scaleFactor)
    }

    @IBAction func zoomIn(_ sender: Any) {
        zoomLevel = min(zoomLevel + 1, zoomLevels.endIndex - 1)
    }

    @IBAction func zoomOut(_ sender: Any) {
        zoomLevel = max(zoomLevel - 1, zoomLevels.startIndex)
    }

    // Drag background to pan
    override func mouseDragged(with event: NSEvent) {
        if let clipView = superview as? NSClipView {
            var origin = clipView.bounds.origin
            origin.x -= event.deltaX
            origin.y -= event.deltaY
            self.scroll(origin)
        }
    }

    // MARK: - Selection

    private(set) var selectedStellars: [StellarView] = []

    override func selectAll(_ sender: Any?) {
        controller.stellarTable.selectAll(self)
    }

    // Click background to deselect (if not holding shift or command and not dragging)
    // Double click to create stellar
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
            if !toggle,
               let e = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]),
               e.type == .leftMouseUp {
                controller.stellarTable.deselectAll(self)
            }
        } else if let invert = transform.inverted() {
            let point = self.convert(event.locationInWindow, from: nil)
            controller.createStellar(position: invert.transform(point))
        }
    }

    // Click stellar to select
    // Double click to open selected stellars
    func mouseDown(stellar: StellarView, with event: NSEvent) {
        let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        if event.clickCount == 1 || toggle {
            dragOrigin = self.convert(event.locationInWindow, from: nil)
            window?.makeFirstResponder(self)
            guard toggle || !stellar.isHighlighted else {
                return
            }
            if !toggle {
                for view in selectedStellars {
                    view.isHighlighted = false
                }
            }
            stellar.isHighlighted = toggle ? !stellar.isHighlighted : true
            self.restackStellars()
            controller.syncSelectionFromView(clicked: stellar)
        } else {
            for view in selectedStellars {
                controller.manager.open(resource: view.resource)
            }
        }
    }

    // MARK: - Move stellars

    private var isMovingStellars = false
    private var dragOrigin: NSPoint?

    // Arrow keys to move stellars
    override func keyDown(with event: NSEvent) {
        let delta = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.specialKey {
        case NSEvent.SpecialKey.leftArrow:
            self.moveStellars(x: 0 - delta, y: 0)
        case NSEvent.SpecialKey.rightArrow:
            self.moveStellars(x: delta, y: 0)
        case NSEvent.SpecialKey.upArrow:
            self.moveStellars(x: 0, y: 0 - delta)
        case NSEvent.SpecialKey.downArrow:
            self.moveStellars(x: 0, y: delta)
        default:
            // Pass other key events to the table view for type-to-select
            controller.stellarTable.keyDown(with: event)
            return
        }
        // Debounce saving
        if window?.nextEvent(matching: .keyDown, until: Date(timeIntervalSinceNow: 0.2), inMode: .eventTracking, dequeue: false) == nil {
            self.applyMove()
        }
    }

    // Drag stellar to move
    func mouseDragged(stellar: StellarView, with event: NSEvent) {
        guard let dragOrigin, event.deltaX != 0 || event.deltaY != 0 else {
            return
        }
        let origin = self.convert(event.locationInWindow, from: nil).constrained(within: bounds)
        self.moveStellars(x: origin.x - dragOrigin.x, y: origin.y - dragOrigin.y)
        self.dragOrigin = origin
        self.autoscroll(with: event)
    }

    // Release to apply move
    func mouseUp(stellar: StellarView, with event: NSEvent) {
        dragOrigin = nil
        guard isMovingStellars else {
            return
        }
        self.applyMove()
        isMovingStellars = false
    }

    private func moveStellars(x: Double, y: Double) {
        for view in selectedStellars {
            view.point.x += x
            view.point.y += y
        }
        isMovingStellars = true
    }

    private func applyMove() {
        guard let invert = transform.inverted() else {
            return
        }
        let term = selectedStellars.count == 1 ? "Stellar Object" : "Stellar Objects"
        undoManager?.setActionName("Move \(term)")
        for view in selectedStellars {
            view.move(to: invert.transform(view.point))
        }
    }

    // Escape to cancel move
    override func cancelOperation(_ sender: Any?) {
        dragOrigin = nil
        guard isMovingStellars else {
            return
        }
        for view in selectedStellars {
            view.updateFrame()
        }
        isMovingStellars = false
    }
    
    // Handlers from galaxy view preserved in case we need them
    func rightMouseDown(stellar: StellarView, with event: NSEvent) {
    }

    func rightMouseDragged(stellar: StellarView, with event: NSEvent) {
    }

    func mouseEntered(stellar: StellarView, with event: NSEvent) {
    }

    func mouseExited(stellar: StellarView, with event: NSEvent) {
    }

    func rightMouseUp(stellar: StellarView, with event: NSEvent) {
    }
}
