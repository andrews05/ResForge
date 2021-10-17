import Cocoa

class DataView: NSView {
    // Data cells use flipped coordinates, drawing from top to bottom
    override var isFlipped: Bool {
        return true
    }
}
