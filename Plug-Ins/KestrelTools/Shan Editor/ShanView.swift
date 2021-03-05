import Cocoa

class ShanView: NSView {
    @IBOutlet weak var controller: ShanWindowController!
    private var fillColor = NSColor.black
    private var borderColor = NSColor.gray
    public override func draw(_ dirtyRect: NSRect) {
        guard controller.currentFrame >= 0 else {
            return
        }
        
        NSGraphicsContext.current?.cgContext.interpolationQuality = .none
        fillColor.setFill()
        dirtyRect.fill()
        for layer in controller.layers {
            layer.draw(dirtyRect)
        }
        
        // Calculate transform for exit points
        var transform = AffineTransform(translationByX: dirtyRect.midX, byY: dirtyRect.midY)
        let angle = CGFloat(controller.framesPerSet-controller.currentFrame)/CGFloat(controller.framesPerSet) * 360
        let compress = 91...269 ~= angle ? (x: controller.downCompressX, y: controller.downCompressY) : (x: controller.upCompressX, y: controller.upCompressY)
        transform.scale(x: compress.x > 0 ? compress.x/100 : 1, y: compress.y > 0 ? compress.y/100 : 1)
        transform.rotate(byDegrees: angle)
        for points in controller.pointLayers {
            points.draw(transform)
        }
        
        borderColor.setFill()
        dirtyRect.frame()
    }
    
    // Toggle black background on click
    override func mouseDown(with event: NSEvent) {
        self.borderColor = self.fillColor == .black ? .quaternaryLabelColor : .gray
        self.fillColor = self.fillColor == .black ? .gridColor : .black
    }
}
