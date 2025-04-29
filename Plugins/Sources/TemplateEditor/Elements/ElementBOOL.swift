import Foundation

class ElementBOOL: ElementBFLG<UInt16> {
    @objc override var value: Bool {
        get { tValue >= 0x100 }
        set { tValue = newValue ? 0x100 : 0 }
    }
}
