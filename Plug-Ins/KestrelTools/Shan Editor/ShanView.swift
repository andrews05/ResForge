import Cocoa

class ShanView: NSView {
    @IBOutlet var controller: ShanWindowController!
    // This override ensures crisp rendering of 72-dpi images on retina displays.
    public override func draw(_ dirtyRect: NSRect) {
        guard controller.currentFrame >= 0 else {
            return
        }
        
        NSGraphicsContext.current?.cgContext.interpolationQuality = .none
        NSColor.black.setFill()
        dirtyRect.fill()
        for layer in controller.layers {
            layer.draw(dirtyRect)
        }
    }
}
