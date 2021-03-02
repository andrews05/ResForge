import Cocoa

class WeaponLayer: ShieldLayer {
    @objc dynamic var weaponDecay: Int16 = 0
    
    override func load(_ shan: Shan) {
        self.spriteID = shan.weaponSprite
        weaponDecay = shan.weaponDecay
    }
    
    override func nextFrame() {
        if !enabled && alpha > 0 {
            // Weapon decay roughly means drop this many transparency levels every 3 frames
            alpha -= CGFloat(weaponDecay) * SpriteLayer.TransparencyStep / 3
        }
    }
}
