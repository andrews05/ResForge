import Cocoa

class AltLayer: SpriteLayer {
    override var operation: NSCompositingOperation { .sourceOver }
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.altSprite
    }
}
