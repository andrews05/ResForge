import Cocoa

class EngineLayer: SpriteLayer {
    override var alpha: CGFloat {
        get { super.alpha + CGFloat.random(in: -0.2..<0) }
        set { }
    }
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.engineSprite
    }
    
    override func nextFrame() {
        if enabled && super.alpha < 1 {
            super.alpha += 1/32
        } else if !enabled && super.alpha > 0 {
            super.alpha -= 1/32
        }
    }
}
