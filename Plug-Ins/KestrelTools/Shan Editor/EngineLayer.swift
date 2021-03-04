import Cocoa

class EngineLayer: ShieldLayer {
    override var alpha: CGFloat {
        get {
            // A rough approximation of Nova's engine flicker
            return super.alpha + CGFloat.random(in: -0.2..<0)
        }
        set { }
    }
    
    override func nextFrame() {
        if enabled && super.alpha < 1 {
            super.alpha += Self.TransparencyStep
        } else if !enabled && super.alpha > 0 {
            super.alpha -= Self.TransparencyStep
        }
    }
}
