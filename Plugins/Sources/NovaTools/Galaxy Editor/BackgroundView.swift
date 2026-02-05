import AppKit
import RFSupport

class BackgroundView: NSView, CALayerDelegate, NSViewLayerContentScaleDelegate {
    @IBOutlet weak var controller: GalaxyWindowController!

    override var isFlipped: Bool { true }
    override var subviews: [NSView] {
        didSet {
            self.transformSubviews()
        }
    }

    func transformSubviews() {
        for view in controller.nebulaViews.values {
            view.updateFrame()
        }
    }

    // MARK: - Drawing

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.contentsScale = window?.backingScaleFactor ?? 1
        layer.backgroundColor = .black
        layer.delegate = self
        layer.setNeedsDisplay()
        return layer
    }

    nonisolated func layer(_ layer: CALayer, shouldInheritContentsScale newScale: CGFloat, from window: NSWindow) -> Bool {
        return true
    }

    func draw(_ layer: CALayer, in ctx: CGContext) {
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

        // Center lines
        NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1).setFill()
        NSRect(x: bounds.midX, y: 0, width: 1, height: bounds.height).frame()
        NSRect(x: 0, y: bounds.midY, width: bounds.width, height: 1).frame()
    }

    // MARK: - Mouse Events

    // Click background to deselect (if not holding shift or command and not dragging)
    // Double click to create system
    // Note: This handler needs to be in the here rather than the GalaxyView, otherwise it will block mouseDown events on NebulaViews
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            let toggle = event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command)
            if !toggle,
               let e = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]),
               e.type == .leftMouseUp {
                controller.resourceTable.deselectAll(self)
            }
        } else if let invert = controller.galaxyView.transform.inverted() {
            let point = self.convert(event.locationInWindow, from: nil)
            controller.createSystem(position: invert.transform(point))
        }
    }
}
