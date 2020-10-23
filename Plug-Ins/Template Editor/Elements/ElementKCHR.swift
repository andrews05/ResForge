import Cocoa

class ElementKCHR: ElementKBYT<UInt8> {
    @objc private var value: String {
        get {
            tValue == 0 ? "" : String(bytes: [tValue], encoding: .macOSRoman)!
        }
        set {
            tValue = newValue.data(using: .macOSRoman)?.first ?? 0
        }
    }
    
    override class var formatter: Formatter? {
        return ElementCHAR.formatter
    }
}
