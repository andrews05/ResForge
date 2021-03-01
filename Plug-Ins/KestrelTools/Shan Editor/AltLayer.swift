import Cocoa

class AltLayer: SpriteLayer {
    override var operation: NSCompositingOperation { .sourceOver }
    @objc dynamic var altSets: Int16 = 0
    private var currentSet = 0
    private var frameCount = 0
    override var currentFrame: NSBitmapImageRep? {
        guard frames.count > 0 else {
            return nil
        }
        let index = (Int(controller.framesPerSet) * currentSet) + controller.currentFrame
        return frames[index % frames.count]
    }
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.altSprite
        altSets = shan.altSets
    }
    
    override func nextFrame() {
        if enabled {
            frameCount += 1
            if frameCount >= controller.animationDelay {
                currentSet = (currentSet + 1) % Int(altSets)
                frameCount = 0
            }
        }
    }
}
