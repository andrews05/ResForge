import Cocoa

class AltLayer: SpriteLayer {
    override var operation: NSCompositingOperation { .sourceOver }
    override var alpha: CGFloat {
        get {
            if !enabled {
                return 0
            }
            return CGFloat(32-controller.baseLayer.baseTransparency) * SpriteLayer.TransparencyStep
        }
        set { }
    }
    override var currentFrame: NSBitmapImageRep? {
        guard frames.count > 0 else {
            return nil
        }
        let index = (controller.framesPerSet * currentSet) + controller.currentFrame
        return frames[index % frames.count]
    }
    @objc dynamic var altSets: Int16 = 0
    @objc dynamic var hideDisabled = false
    private var currentSet = 0
    private var frameCount = 0
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.altSprite
        altSets = shan.altSets
        hideDisabled = shan.flags.contains(.hideAltDisabled)
    }
    
    override func nextFrame() {
        if enabled && altSets > 0 {
            frameCount += 1
            if frameCount >= controller.animationDelay {
                currentSet = (currentSet + 1) % Int(altSets)
                frameCount = 0
            }
        }
    }
}
