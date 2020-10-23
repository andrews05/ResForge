import Cocoa

class ElementKTYP: ElementKBYT<UInt32> {
    @objc private var value: String {
        get { tValue.stringValue }
        set { tValue = FourCharCode(newValue) }
    }
    
    override class var formatter: Formatter? {
        return ElementTNAM.formatter
    }
}
