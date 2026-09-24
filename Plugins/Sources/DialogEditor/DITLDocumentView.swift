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
}
