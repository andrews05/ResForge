import Cocoa

class BaseLayer: SpriteLayer {
    override var operation: NSCompositingOperation { .sourceOver }
    override var alpha: CGFloat {
        get {
            if !enabled {
                return 0
            }
            return CGFloat(32-baseTransparency) * SpriteLayer.TransparencyStep
        }
        set { }
    }
    @objc dynamic var baseTransparency: Int16 = 0
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.baseSprite
        baseTransparency = shan.baseTransparency
    }
}
