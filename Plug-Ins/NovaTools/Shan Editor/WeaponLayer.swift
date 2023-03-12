import Cocoa

class WeaponLayer: ShieldLayer {
    @objc dynamic var decay: Int16 = 0

    override func nextFrame() {
        if !enabled && alpha > 0 {
            // Weapon decay roughly means drop this many transparency levels every 3 frames
            alpha -= CGFloat(decay) * Self.TransparencyStep / 3
        }
    }
}
