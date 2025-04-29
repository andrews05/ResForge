import AppKit

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

    override func nextFrame() {
        if !enabled && alpha > 0 {
            alpha -= Self.TransparencyStep
        }
    }
}
