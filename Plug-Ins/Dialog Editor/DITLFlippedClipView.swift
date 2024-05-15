import AppKit


/// View that makes our document view top-left aligned inside the scroll view:
class DITLFlippedClipView : NSClipView {
    public override var isFlipped: Bool {
        get {
            return true
        }
        set(newValue) {
            
        }
    }
}
