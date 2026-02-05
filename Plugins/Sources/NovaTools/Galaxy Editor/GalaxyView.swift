import AppKit
import RFSupport

class GalaxyView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: GalaxyWindowController!
    @IBOutlet var scaleText: NSTextField!
    private(set) var transform = AffineTransform()
    var isSavingItem = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }
    override var subviews: [NSView] {
        didSet {
            self.transformSubviews()
            self.restackViews()
            undoManager?.removeAllActions()
        }
    }

    override func awakeFromNib() {
        self.updateScale()
        self.centerScroll(frame.center)
    }

    private func transformSubviews() {
        for view in controller.systemViews.values {
            view.showName = zoomLevel >= 3
            view.updateFrame()
        }
        needsDisplay = true
    }

    func restackViews() {
        // Keep track of occupied locations - only the first system at a given point will be displayed
        var topViews: [NSPoint.Hash: SystemView] = [:]
        selectedItems = []
        for view in controller.systemViews.values {
            view.highlightCount = 1
            let key = view.point.hashable
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
                selectedItems.append(view)
            }
        }
        for view in controller.nebulaViews.values {
            if view.isHighlighted {
                selectedItems.append(view)
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
        layer.delegate = self
        return layer
    }

    nonisolated func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        return true
    }

    func draw(_ layer: CALayer, in ctx: CGContext) {
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

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

    // MARK: - Zoom

    private let zoomLevels: [Double] = [27/64, 9/16, 3/4, 1, 4/3, 16/9, 64/27]
    private var zoomLevel = 4 {
        didSet {
            if zoomLevel != oldValue, let enclosingScrollView, let inverse = transform.inverted() {
                let oldPos = inverse.transform(enclosingScrollView.documentVisibleRect.center)

                self.updateScale()
                self.transformSubviews()
                controller.backgroundView.transformSubviews()

                self.centerScroll(transform.transform(oldPos))
                enclosingScrollView.flashScrollers()
            }
        }
    }

    private func updateScale() {
        let scaleFactor = zoomLevels[zoomLevel]
        transform = AffineTransform(translationByX: frame.midX, byY: frame.midY)
        transform.scale(scaleFactor)
        scaleText.stringValue = String(format: "%.3g%%", scaleFactor * 100)
    }

    @IBAction func zoomIn(_ sender: Any) {
        zoomLevel = min(zoomLevel+1, 6)
    }

    @IBAction func zoomOut(_ sender: Any) {
        zoomLevel = max(zoomLevel-1, 0)
    }

    // MARK: - Selection

    private(set) var selectedItems: [ItemView] = []

    override func selectAll(_ sender: Any?) {
        controller.resourceTable.selectAll(self)
    }

    // Click item to select
    // Double click to open selected items
    func mouseDown(item: ItemView, with event: NSEvent) {
        let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
        if event.clickCount == 1 || toggle {
            dragOrigin = self.convert(event.locationInWindow, from: nil)
            window?.makeFirstResponder(self)
            guard toggle || !item.isHighlighted else {
                return
            }
            let state = toggle ? !item.isHighlighted : true
            for view in controller.systemViews.values {
                // Select/deselect all enabled systems at the same point
                if view.isEnabled && view.point == item.point {
                    view.isHighlighted = state
                } else if !toggle {
                    view.isHighlighted = false
                }
            }
            if !toggle {
                for view in controller.nebulaViews.values {
                    view.isHighlighted = false
                }
            }
            item.isHighlighted = state
            self.restackViews()
            controller.syncSelectionFromView(clicked: item)
        } else {
            for view in selectedItems {
                controller.manager.open(resource: view.resource)
            }
        }
    }

    // MARK: - Move systems

    private var isMovingItems = false
    private var dragOrigin: NSPoint?

    // Arrow keys to move items, space to scroll to center
    override func keyDown(with event: NSEvent) {
        let delta = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        switch event.specialKey {
        case .leftArrow:
            self.moveItems(x: 0 - delta, y: 0)
        case .rightArrow:
            self.moveItems(x: delta, y: 0)
        case .upArrow:
            self.moveItems(x: 0, y: 0 - delta)
        case .downArrow:
            self.moveItems(x: 0, y: delta)
        case _ where event.characters == " ":
            self.centerScroll(frame.center)
            return
        default:
            // Pass other key events to the table view for type-to-select
            controller.resourceTable.keyDown(with: event)
            return
        }
        // Debounce saving
        if window?.nextEvent(matching: .keyDown, until: Date(timeIntervalSinceNow: 0.2), inMode: .eventTracking, dequeue: false) == nil {
            self.applyMove()
        }
    }

    // Drag to move items, or pan if no drag origin
    override func mouseDragged(with event: NSEvent) {
        if let dragOrigin {
            guard event.deltaX != 0 || event.deltaY != 0 else {
                return
            }
            let origin = self.convert(event.locationInWindow, from: nil).constrained(within: bounds)
            self.moveItems(x: origin.x - dragOrigin.x, y: origin.y - dragOrigin.y)
            self.dragOrigin = origin
            self.autoscroll(with: event)
        } else if let clipView = enclosingScrollView?.contentView {
            var origin = clipView.bounds.origin
            origin.x -= event.deltaX
            origin.y += event.deltaY
            clipView.scroll(origin)
        }
    }

    // Release to apply move
    func mouseUp(item: ItemView, with event: NSEvent) {
        dragOrigin = nil
        guard isMovingItems else {
            return
        }
        self.applyMove()
        isMovingItems = false
    }

    private func moveItems(x: Double, y: Double) {
        for view in selectedItems {
            view.point.x += x
            view.point.y += y
        }
        if !isMovingItems {
            // Restack after initial move in case any obscured systems need to be revealed
            self.restackViews()
            isMovingItems = true
        }
        needsDisplay = true
    }

    private func applyMove() {
        guard let invert = transform.inverted() else {
            return
        }
        let term = if selectedItems is [SystemView] {
            selectedItems.count == 1 ? "System" : "Systems"
        } else if selectedItems is [NebulaView] {
            selectedItems.count == 1 ? "Nebula" : "Nebulae"
        } else {
            selectedItems.count == 1 ? "Item" : "Items"
        }
        undoManager?.setActionName("Move \(term)")
        self.beginApplyMove()
        for view in selectedItems {
            view.move(to: invert.transform(view.point))
        }
        self.endApplyMove()
    }

    private func beginApplyMove() {
        undoManager?.registerUndo(withTarget: self) { $0.endApplyMove() }
    }

    private func endApplyMove() {
        undoManager?.registerUndo(withTarget: self) { $0.beginApplyMove() }
        self.restackViews()
    }

    // Escape to cancel move
    override func cancelOperation(_ sender: Any?) {
        dragOrigin = nil
        guard isMovingItems else {
            return
        }
        for view in selectedItems {
            view.updateFrame()
        }
        self.restackViews()
        isMovingItems = false
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
