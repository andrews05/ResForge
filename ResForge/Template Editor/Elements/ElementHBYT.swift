import Cocoa
import RFSupport

// Implements HBYT, HWRD, HLNG, HQWD
class ElementHBYT<T: FixedWidthInteger & UnsignedInteger>: CasedElement {
    var tValue: T = 0
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        switch T.bitWidth/8 {
        case 4:
            self.width = 90
        case 8:
            self.width = 150
        default:
            break
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override var formatter: Formatter {
        self.sharedFormatter("HEX\(T.bitWidth)") { HexFormatter<T>() }
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
