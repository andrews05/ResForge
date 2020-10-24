import RKSupport

class ElementCHAR: ElementDBYT<UInt8> {
    @objc private var value: String {
        get {
            tValue == 0 ? "" : String(bytes: [tValue], encoding: .macOSRoman)!
        }
        set {
            tValue = newValue.data(using: .macOSRoman)?.first ?? 0
        }
    }
    
    override class var formatter: Formatter? {
        let formatter = MacRomanFormatter()
        formatter.stringLength = 1
        formatter.exactLengthRequired = true
        return formatter
    }
}
