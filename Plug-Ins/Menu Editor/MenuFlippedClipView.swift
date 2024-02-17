import Cocoa


/// View that makes our document view top-left aligned inside the scroll view:
class MenuFlippedClipView : NSClipView {
    public override var isFlipped: Bool {
        get {
            return true
        }
        set(newValue) {
            
        }
    }
}
