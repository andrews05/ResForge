import AppKit


/// The "document area" of our scroll view, in which we show the DITL items.
class DITLDocumentView: NSView {
    var dialogBounds: NSRect?
    var items: [DITLItemView] {
        subviews as? [DITLItemView] ?? []
    }
    var controller: DialogEditor? {
        window?.windowController as? DialogEditor
    }
    var backgroundImage: NSImage? {
        didSet {
            needsDisplay = true
        }
    }
    private var movingItems: [DITLItemView]? = nil
    @IBOutlet var widthConstraint: NSLayoutConstraint!
    @IBOutlet var heightConstraint: NSLayoutConstraint!

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var subviews: [NSView] {
        didSet {
            self.updateMinSize()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        if let dialogBounds {
            if let backgroundImage {
                backgroundImage.draw(in: dialogBounds, from: .zero, operation: .copy, fraction: 0.5, respectFlipped: true, hints: nil)
            } else {
                NSColor.white.setFill()
                dialogBounds.fill()
                NSColor.systemGray.setFill()
                dialogBounds.insetBy(dx: -1, dy: -1).frame()
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        controller?.deselectAll(self)
    }

    func updateMinSize() {
        var minSize = dialogBounds?.size ?? NSSize()
        for item in items {
            let itemBox = item.frame
            minSize.width = max(itemBox.maxX, minSize.width)
            minSize.height = max(itemBox.maxY, minSize.height)
        }
        widthConstraint.constant = minSize.width + 16
        heightConstraint.constant = minSize.height + 16
    }

    // Arrow keys to move items
    override func keyDown(with event: NSEvent) {
        let delta = event.modifierFlags.contains(.shift) ? 10.0 : 1.0
        let offset: NSPoint
        switch event.specialKey {
        case .leftArrow:
            offset = NSPoint(x: -delta, y: 0)
        case .rightArrow:
            offset = NSPoint(x: delta, y: 0)
        case .upArrow:
            offset = NSPoint(x: 0, y: -delta)
        case .downArrow:
            offset = NSPoint(x: 0, y: delta)
        default:
            super.keyDown(with: event)
            return
        }

        if movingItems == nil {
            let selection = items.filter(\.selected)
            guard !selection.isEmpty else {
                return
            }
            movingItems = selection
            undoManager?.beginUndoGrouping()
            let action = selection.count == 1 ? "Move Item" : "MoveItems"
            undoManager?.setActionName(NSLocalizedString(action, comment: ""))
            controller?.setDocumentEdited(true)
        }

        self.moveItems(movingItems!, x: offset.x, y: offset.y)

        // Debounce undo tracking
        if window?.nextEvent(matching: .keyDown, until: Date(timeIntervalSinceNow: 0.2), inMode: .eventTracking, dequeue: false) == nil {
            undoManager?.endUndoGrouping()
            movingItems = nil
        }
    }

    func moveItems(_ items: [DITLItemView], x: Double, y: Double) {
        for view in items {
            view.frame = view.frame.offsetBy(dx: x, dy: y)
        }
        undoManager?.registerUndo(withTarget: self) { $0.moveItems(items, x: -x, y: -y) }
        self.updateMinSize()
    }
}
