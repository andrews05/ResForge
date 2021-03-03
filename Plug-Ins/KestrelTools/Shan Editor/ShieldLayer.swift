import Cocoa

class ShieldLayer: SpriteLayer {
    override var enabled: Bool {
        didSet {
            alpha = 1
        }
    }
    
    // This layer should be initially disabled
    override init() {
        super.init()
        self.enabled = false
        super.alpha = 0
    }
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.shieldSprite
    }
    
    override func nextFrame() {
        if !enabled && alpha > 0 {
            alpha -= SpriteLayer.TransparencyStep
        }
    }
}
