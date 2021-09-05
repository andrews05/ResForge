import Cocoa

// Implements HBYT, HWRD, HLNG, HLLG
class ElementHBYT<T: FixedWidthInteger & UnsignedInteger>: ElementDBYT<T> {
    override class var formatter: Formatter? {
        return HexFormatter<T>()
    }
}

class HexFormatter<T: FixedWidthInteger & UnsignedInteger>: Formatter {
    private let charCount: Int
    
    override init() {
        charCount = T.bitWidth/4
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func string(for obj: Any?) -> String? {
        if let obj = obj as? NSNumber {
            return String(format: "0x%0\(charCount)llX", obj.intValue)
        }
        return nil
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        var string = string
        if string.first == "$" {
            string = String(string.dropFirst())
        }
        var value: UInt64 = 0
        let scanner = Scanner(string: string)
        scanner.scanHexInt64(&value)
        if !scanner.isAtEnd {
            error?.pointee = NSLocalizedString("The value is not a valid hex string.", comment: "") as NSString
            return false
        }
        if value > T.max {
            error?.pointee = NSLocalizedString("The value is too large.", comment: "") as NSString
            return false
        }
        obj?.pointee = value as NSNumber
        return true
    }
}
