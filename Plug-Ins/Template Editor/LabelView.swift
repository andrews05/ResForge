import Cocoa

class LabelView: NSTableCellView {
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        self.window?.makeFirstResponder(self)
    }
    
    override var focusRingMaskBounds: NSRect {
        return self.textField!.frame
    }
    
    override func drawFocusRingMask() {
        self.focusRingMaskBounds.fill()
    }
}
