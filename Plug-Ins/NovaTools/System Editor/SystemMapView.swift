import AppKit
import RFSupport

class SystemMapView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: SystemWindowController!
    @IBOutlet var scaleText: NSTextField!
    private(set) var transform = AffineTransform()
    var isSavingStellar = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func awakeFromNib() {
        self.updateScale()
        self.centerScroll(frame.center)
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
        // Grid lines
        let grid = NSBezierPath()
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).setStroke()
        let gridSpacing = 200 * zoomLevels[zoomLevel]
        for i in stride(from: gridSpacing + 0.5, to: bounds.width, by: gridSpacing) {
            grid.move(to: NSPoint(x: bounds.minX, y: i))
            grid.line(to: NSPoint(x: bounds.maxX, y: i))
            grid.move(to: NSPoint(x: i, y: bounds.minY))
            grid.line(to: NSPoint(x: i, y: bounds.maxY))
        }
        grid.stroke()

        // Centre lines
        let path = NSBezierPath()
        NSColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1).setStroke()
        path.move(to: NSPoint(x: bounds.minX, y: bounds.midY + 0.5))
        path.line(to: NSPoint(x: bounds.maxX, y: bounds.midY + 0.5))
        path.move(to: NSPoint(x: bounds.midX + 0.5, y: bounds.minY))
        path.line(to: NSPoint(x: bounds.midX + 0.5, y: bounds.maxY))
        // Boundary (visible only when document is smaller than clip view)
        path.appendRect(bounds.insetBy(dx: -0.5, dy: -0.5))
        // Default safe jump distance
        let jumpZone = transform.transform(NSRect(x: -1000, y: -1000, width: 2000, height: 2000))
        path.appendOval(in: jumpZone)
        path.stroke()
    }

    // MARK: - Pan and zoom

    private let zoomLevels: [Double] = [1/40, 1/20, 1/10, 1/5, 1/2, 1]
    private var zoomLevel = 4 {
        didSet {
            if zoomLevel != oldValue, let enclosingScrollView, let inverse = transform.inverted() {
                let oldPos = inverse.transform(enclosingScrollView.documentVisibleRect.center)

                self.updateScale()
                self.transformSubviews()

                self.centerScroll(transform.transform(oldPos))
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
        scaleText.stringValue = String(format: "%.3g%%", scaleFactor * 100)
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

    // Arrow keys to move stellars, space to scroll to center
    override func keyDown(with event: NSEvent) {
        let delta = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.specialKey {
        case .leftArrow:
            self.moveStellars(x: 0 - delta, y: 0)
        case .rightArrow:
            self.moveStellars(x: delta, y: 0)
        case .upArrow:
            self.moveStellars(x: 0, y: 0 - delta)
        case .downArrow:
            self.moveStellars(x: 0, y: delta)
        case _ where event.characters == " ":
            self.centerScroll(frame.center)
            return
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

    // Hold option while moving to snap
    override func flagsChanged(with event: NSEvent) {
        if isMovingStellars {
            let snap = event.modifierFlags.contains(.option)
            self.moveStellars(x: 0, y: 0, snap: snap)
        }
    }

    // Drag stellar to move
    func mouseDragged(stellar: StellarView, with event: NSEvent) {
        guard let dragOrigin, event.deltaX != 0 || event.deltaY != 0 else {
            return
        }
        let origin = self.convert(event.locationInWindow, from: nil).constrained(within: bounds)
        let snap = event.modifierFlags.contains(.option)
        self.moveStellars(x: origin.x - dragOrigin.x, y: origin.y - dragOrigin.y, snap: snap)
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

    private func moveStellars(x: Double, y: Double, snap: Bool = false) {
        for view in selectedStellars {
            view.setPoint(NSPoint(x: view.point.x + x, y: view.point.y + y), snapSize: snap ? 10 : nil)
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
            // Use the frame center rather than view.point in case of snapping
            view.move(to: invert.transform(view.frame.center))
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
}
