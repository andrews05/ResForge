import Cocoa

class EngineLayer: SpriteLayer {
    override var alpha: CGFloat {
        get { super.alpha + CGFloat.random(in: -0.2..<0) }
        set { }
    }
    
    override init() {
        super.init()
        self.enabled = false
        super.alpha = 0
    }
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.engineSprite
    }
    
    override func nextFrame() {
        if enabled && super.alpha < 1 {
            super.alpha += SpriteLayer.TransparencyStep
        } else if !enabled && super.alpha > 0 {
            super.alpha -= SpriteLayer.TransparencyStep
        }
    }
}
