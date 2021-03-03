import Cocoa

class EngineLayer: ShieldLayer {
    override var alpha: CGFloat {
        get {
            // A rough approximation of Nova's engine flicker
            return super.alpha + CGFloat.random(in: -0.2..<0)
        }
        set { }
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
