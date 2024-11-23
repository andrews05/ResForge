import AppKit
import RFSupport

class GalaxyView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: GalaxyWindowController!
    private(set) var transform = AffineTransform()
    var isSavingSystem = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override var subviews: [NSView] {
        didSet {
            self.transformSubviews()
            self.restackSystems()
            undoManager?.removeAllActions()
        }
    }

    override func awakeFromNib() {
        transform.translate(x: frame.midX, y: frame.midY)
        transform.scale(zoomLevels[zoomLevel])
    }

    private func transformSubviews() {
        for view in controller.systemViews.values {
            view.showName = zoomLevel >= 3
            view.updateFrame()
        }
        needsDisplay = true
    }

    func restackSystems() {
        // Keep track of occupied locations - only the first system at a given point will be displayed
        // Note NSPoint only conforms to Hashable since macOS 15
        var topViews: [Int: SystemView] = [:]
        selectedSystems = []
        for view in controller.systemViews.values {
            view.highlightCount = 1
            let key = view.point.hashValue
            if let topView = topViews[key] {
                if !view.isHighlighted {
                    view.isHidden = true
                } else if !topView.isHighlighted {
                    // The current top view is not part of the selection, swap it with this one
                    topView.isHidden = true
                    topViews[key] = view
                    view.isHidden = false
                } else if topView != view {
                    topView.highlightCount += 1
                    view.isHidden = true
                }
            } else {
                // No current top view, set it to this one
                topViews[key] = view
                view.isHidden = false
            }
            if view.isHighlighted {
                selectedSystems.append(view)
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

    // MARK: - Pan and zoom

    private let zoomLevels: [Double] = [8/19, 9/16, 3/4, 1, 4/3, 16/9, 19/8]
    private var zoomLevel = 4 {
        didSet {
            if zoomLevel != oldValue, let enclosingScrollView, let inverse = transform.inverted() {
                let documentRect = enclosingScrollView.documentVisibleRect
                let oldPos = inverse.transform(NSPoint(x: documentRect.midX, y: documentRect.midY))

                transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
                transform.scale(zoomLevels[zoomLevel])
                self.transformSubviews()

                let newPos = transform.transform(oldPos)
                self.scroll(NSPoint(x: newPos.x - documentRect.width / 2, y: newPos.y - documentRect.height / 2))
                enclosingScrollView.flashScrollers()
            }
        }
    }

    @IBAction func zoomIn(_ sender: Any) {
        zoomLevel = min(zoomLevel+1, 6)
    }

    @IBAction func zoomOut(_ sender: Any) {
        zoomLevel = max(zoomLevel-1, 0)
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

    private(set) var selectedSystems: [SystemView] = []

    override func selectAll(_ sender: Any?) {
        controller.systemTable.selectAll(self)
    }

    // Click background to deselect (if not holding shift or command and not dragging)
    // Double click to create system
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
            if !toggle,
               let e = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]),
               e.type == .leftMouseUp {
                controller.systemTable.deselectAll(self)
            }
        } else if let invert = transform.inverted() {
            let point = self.convert(event.locationInWindow, from: nil)
            controller.createSystem(position: invert.transform(point))
        }
    }

    // Click system to select
    // Double click to open selected systems
    func mouseDown(system: SystemView, with event: NSEvent) {
        let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        if event.clickCount == 1 || toggle {
            dragOrigin = self.convert(event.locationInWindow, from: nil)
            window?.makeFirstResponder(self)
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
        } else {
            for view in selectedSystems {
                controller.manager.open(resource: view.resource)
            }
        }
    }

    // MARK: - Move systems

    private var isMovingSystems = false
    private var dragOrigin: NSPoint?

    // Arrow keys to move systems
    override func keyDown(with event: NSEvent) {
        let delta = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.specialKey {
        case .leftArrow:
            self.moveSystems(x: 0 - delta, y: 0)
        case .rightArrow:
            self.moveSystems(x: delta, y: 0)
        case .upArrow:
            self.moveSystems(x: 0, y: 0 - delta)
        case .downArrow:
            self.moveSystems(x: 0, y: delta)
        default:
            // Pass other key events to the table view for type-to-select
            controller.systemTable.keyDown(with: event)
            return
        }
        // Debounce saving
        if window?.nextEvent(matching: .keyDown, until: Date(timeIntervalSinceNow: 0.2), inMode: .eventTracking, dequeue: false) == nil {
            self.applyMove()
        }
    }

    // Drag system to move
    func mouseDragged(system: SystemView, with event: NSEvent) {
        guard let dragOrigin, event.deltaX != 0 || event.deltaY != 0 else {
            return
        }
        let origin = self.convert(event.locationInWindow, from: nil).constrained(within: bounds)
        self.moveSystems(x: origin.x - dragOrigin.x, y: origin.y - dragOrigin.y)
        self.dragOrigin = origin
        self.autoscroll(with: event)
    }

    // Release to apply move
    func mouseUp(system: SystemView, with event: NSEvent) {
        dragOrigin = nil
        guard isMovingSystems else {
            return
        }
        self.applyMove()
        isMovingSystems = false
    }

    private func moveSystems(x: Double, y: Double) {
        for view in selectedSystems {
            view.point.x += x
            view.point.y += y
        }
        if !isMovingSystems {
            // Restack after initial move in case any obscured systems need to be revealed
            self.restackSystems()
            isMovingSystems = true
        }
        needsDisplay = true
    }

    private func applyMove() {
        guard let invert = transform.inverted() else {
            return
        }
        let term = selectedSystems.count == 1 ? "System" : "Systems"
        undoManager?.setActionName("Move \(term)")
        self.beginApplyMove()
        for view in selectedSystems {
            view.move(to: invert.transform(view.point))
        }
        self.endApplyMove()
    }

    private func beginApplyMove() {
        undoManager?.registerUndo(withTarget: self) { $0.endApplyMove() }
    }

    private func endApplyMove() {
        undoManager?.registerUndo(withTarget: self) { $0.beginApplyMove() }
        self.restackSystems()
    }

    // Escape to cancel move
    override func cancelOperation(_ sender: Any?) {
        dragOrigin = nil
        guard isMovingSystems else {
            return
        }
        for view in selectedSystems {
            view.updateFrame()
        }
        self.restackSystems()
        isMovingSystems = false
        needsDisplay = true
    }

    // MARK: - Link systems

    private var linkingLayer = LinkingLayer()

    func layoutSublayers(of layer: CALayer) {
        // The linking layer should always be topmost
        linkingLayer.frame = layer.frame
        layer.addSublayer(linkingLayer)
    }

    // Right mouse down to begin link
    func rightMouseDown(system: SystemView, with event: NSEvent) {
        linkingLayer.source = system
        linkingLayer.targets = []
        linkingLayer.setNeedsDisplay()
    }

    // Drag to draw link
    func rightMouseDragged(system: SystemView, with event: NSEvent) {
        if linkingLayer.source != nil {
            system.updateTrackingAreas() // mouseEntered doesn't work without this??
            linkingLayer.setNeedsDisplay()
        }
    }

    // Mouse entered to select target
    func mouseEntered(system: SystemView, with event: NSEvent) {
        if linkingLayer.source != nil && linkingLayer.source != system {
            linkingLayer.targets.append(system)
        }
    }

    func mouseExited(system: SystemView, with event: NSEvent) {
        if linkingLayer.source != nil {
            linkingLayer.targets.removeAll { $0 == system }
        }
    }

    // Mouse up to add/remove link
    func rightMouseUp(system: SystemView, with event: NSEvent) {
        if let linkSource = linkingLayer.source, let linkTarget = linkingLayer.target {
            let remove = event.modifierFlags.contains(.option)
            let sources = controller.systemViews.values.filter { $0.point == linkSource.point }
            let targets = controller.systemViews.values.filter { $0.point == linkTarget.point }
            for source in sources {
                for target in targets {
                    if remove {
                        source.removeLink(target.resource.id)
                        target.removeLink(source.resource.id)
                    } else {
                        source.addLink(target.resource.id)
                        target.addLink(source.resource.id)
                    }
                }
            }
        }
        linkingLayer.source = nil
        linkingLayer.setNeedsDisplay()
    }
}

extension AffineTransform {
    func transform(_ rect: NSRect) -> NSRect {
        NSRect(origin: transform(rect.origin), size: transform(rect.size))
    }
}

extension NSPoint {
    /// Returns the nearest point to this one that lies within the given rectangle.
    func constrained(within rect: NSRect) -> Self {
        Self(x: min(max(x, rect.minX), rect.maxX), y: min(max(y, rect.minY), rect.maxY))
    }
}
