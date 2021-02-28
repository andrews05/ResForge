import Cocoa

class ShieldLayer: SpriteLayer {
    override func load(_ shan: Shan) {
        self.spriteID = shan.shieldSprite
    }
}
