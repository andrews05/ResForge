import AppKit
import RFSupport

class SystemMapView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: SystemWindowController!
    private(set) var transform = AffineTransform()
    var isSavingStellar = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override var subviews: [NSView] {
        didSet {
            self.transformSubviews()
            self.restackStellars()
            undoManager?.removeAllActions()
        }
    }

    override func awakeFromNib() {
        zoomLevel = 3
    }

    private func transformSubviews() {
        for view in controller.stellarViews.values {
            view.updateFrame()
        }
        needsDisplay = true
    }

    func restackStellars() {
        // Keep track of occupied locations - only the first stellar at a given point will be displayed
        // This logic is inherited from GalaxyView where it's required for replacing systems based on visibilty;
        // it's used here for consistency and just in case there's a reason to do the same with stellars.
        var topViews: [NSPoint: StellarView] = [:]
        selectedStellars = []
        for view in controller.stellarViews.values {
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
            if view.isHighlighted {
                selectedStellars.append(view)
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

        // Centre line
        let path = NSBezierPath()
        NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 0.4).setStroke()
        path.move(to: NSPoint(x: 0, y: frame.size.height / 2 - 0.5))
        path.line(to: NSPoint(x: frame.size.width, y: frame.size.height / 2 - 0.5))
        path.move(to: NSPoint(x: frame.size.width / 2 - 0.5, y: 0))
        path.line(to: NSPoint(x: frame.size.width / 2 - 0.5, y: frame.size.height))
        path.stroke()
    }

    // MARK: - Pan and zoom

    private let zoomLevels: [Double] = [1/16, 1/8, 1/4, 8/19, 9/16, 3/4, 1];
    func scaleFactor(forLevel level: Int) -> CGFloat {
        return zoomLevels[level];
    }
    private var zoomLevel = 0 {
        didSet {
            if zoomLevel != oldValue {
                let oldPos = NSPoint(x: (enclosingScrollView?.documentVisibleRect.midX ?? 0) / frame.size.width, y: (enclosingScrollView?.documentVisibleRect.midY ?? 0) / frame.size.height)
                let scaleFactor = scaleFactor(forLevel: zoomLevel)
                // EVN wraps the player around at ±15000 from the origin, so a stellar could conceivably be placed anywhere within
                // that range
                let calculatedSize = NSSize(width: Int(30000 * scaleFactor), height: Int(30000 * scaleFactor))
                frame.size = calculatedSize

                transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
                transform.scale(scaleFactor)

                self.transformSubviews()

                if let newVisibleRect = enclosingScrollView?.documentVisibleRect {
                    let scrollOrigin = NSPoint(x: oldPos.x * frame.size.width - newVisibleRect.width / 2, y: oldPos.y * frame.size.height - newVisibleRect.height / 2)
                    self.scroll(scrollOrigin)
                }
                enclosingScrollView?.flashScrollers()
            }
        }
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
            let state = toggle ? !stellar.isHighlighted : true
            for view in controller.stellarViews.values {
                // Select/deselect all enabled stellars at the same point
                if view.isEnabled && view.point == stellar.point {
                    view.isHighlighted = state
                } else if !toggle {
                    view.isHighlighted = false
                }
            }
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
        if !isMovingStellars {
            // Restack after initial move in case any obscured stellars need to be revealed
            self.restackStellars()
            isMovingStellars = true
        }
        needsDisplay = true
    }

    private func applyMove() {
        guard let invert = transform.inverted() else {
            return
        }
        let term = selectedStellars.count == 1 ? "Stellar Object" : "Stellar Objects"
        undoManager?.setActionName("Move \(term)")
        self.beginApplyMove()
        for view in selectedStellars {
            view.move(to: invert.transform(view.point))
        }
        self.endApplyMove()
    }

    private func beginApplyMove() {
        undoManager?.registerUndo(withTarget: self) { $0.endApplyMove() }
    }

    private func endApplyMove() {
        undoManager?.registerUndo(withTarget: self) { $0.beginApplyMove() }
        self.restackStellars()
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
        self.restackStellars()
        isMovingStellars = false
        needsDisplay = true
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
