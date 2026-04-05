import Foundation
import RFSupport

// Implements DBYT, DWRD, DLNG, DQWD, UBYT, UWRD, ULNG, UQWD
class ElementDBYT<T: FixedWidthInteger>: RangedElement<T> {
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        switch T.bitWidth/8 {
        case 4:
            blockWidth = 3
        case 8:
            blockWidth = 5
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
        let key = T.isSigned ? "INT" : "UINT"
        return self.sharedFormatter("\(key)\(T.bitWidth)") { IntFormatter(T.self) }
    }
}

// NumberFormatter can't correctly handle UInt64 values above Int64.max.
// Our custom formatter can handle any valid value and is much faster.
class IntFormatter: Formatter {
    var min: Int?
    var max: Int?

    init(min: Int, max: Int) {
        self.min = min
        self.max = max
        super.init()
    }

    init(_ type: any FixedWidthInteger.Type) {
        self.min = Int(exactly: type.min)
        self.max = Int(exactly: type.max)
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func string(for obj: Any?) -> String? {
        return (obj as? NSNumber)?.stringValue
    }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if let min, min < 0 {
            guard let value = Int64(string) else {
                error?.pointee = "The value must be an integer."
                return false
            }
            if let max, value > max {
                error?.pointee = "The maximum value is \(max)." as NSString
                return false
            }
            if value < min {
                error?.pointee = "The minimum value is \(min)." as NSString
                return false
            }
            obj?.pointee = value as NSNumber
        } else {
            guard let value = UInt64(string) else {
                error?.pointee = "The value must be a positive integer."
                return false
            }
            if let max, value > max {
                error?.pointee = "The maximum value is \(max)." as NSString
                return false
            }
            if let min, value < min {
                error?.pointee = "The minimum value is \(min)." as NSString
                return false
            }
            obj?.pointee = value as NSNumber
        }
        return true
    }
}
