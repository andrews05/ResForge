import Cocoa

class ShanView: NSView {
    var shanController: ShanWindowController!
    // This override ensures crisp rendering of 72-dpi images on retina displays.
    public override func draw(_ dirtyRect: NSRect) {
        guard shanController.currentFrame >= 0 else {
            return
        }
        
        NSGraphicsContext.current?.cgContext.interpolationQuality = .none
        NSColor.black.setFill()
        dirtyRect.fill()
        if shanController.currentFrame < shanController.baseFrames.count {
            let frame = shanController.baseFrames[shanController.currentFrame]
            self.draw(bitmap: frame, in: dirtyRect, operation: .sourceOver)
        }
        if shanController.currentFrame < shanController.glowFrames.count {
            let frame = shanController.glowFrames[shanController.currentFrame]
            self.draw(bitmap: frame, in: dirtyRect, operation: .plusLighter)
        }
        if shanController.currentFrame < shanController.lightFrames.count {
            let frame = shanController.lightFrames[shanController.currentFrame]
            self.draw(bitmap: frame, in: dirtyRect, operation: .plusLighter)
        }
    }
    
    private func draw(bitmap: NSBitmapImageRep, in dirtyRect: NSRect, operation: NSCompositingOperation, fraction: CGFloat = 1) {
        let rect = NSMakeRect(dirtyRect.midX-(bitmap.size.width/2), dirtyRect.midY-(bitmap.size.height/2), bitmap.size.width, bitmap.size.height)
        bitmap.draw(in: rect, from: NSZeroRect, operation: operation, fraction: fraction, respectFlipped: true, hints: nil)
    }
}
