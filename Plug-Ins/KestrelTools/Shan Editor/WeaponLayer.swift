import Cocoa

class WeaponLayer: SpriteLayer {
    override func load(_ shan: Shan) {
        self.spriteID = shan.weaponSprite
    }
}
