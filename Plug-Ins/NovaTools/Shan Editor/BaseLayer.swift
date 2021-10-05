import Cocoa

class BaseLayer: SpriteLayer {
    override var operation: NSCompositingOperation { .sourceOver }
    override var alpha: CGFloat {
        get {
            if !enabled {
                return 0
            }
            return CGFloat(32-controller.baseTransparency) * Self.TransparencyStep
        }
        set { }
    }
}
