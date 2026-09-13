import Foundation
import RFSupport

class ElementDOUB: CasedElement {
    @objc private var value: Double = 0

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 6
    }

    override func readData(from reader: BinaryDataReader) throws {
        value = Double(bitPattern: try reader.read())
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }

    override var formatter: Formatter {
        self.sharedFormatter { FloatFormatter<Double>() }
    }
}

// Custom float formatter allows automatic switching between decimal and
// scientific representations, as well as more flexible parsing that can handle
// values such as NaN or INF.
class FloatFormatter<T: BinaryFloatingPoint & LosslessStringConvertible>: NumberFormatter, @unchecked Sendable {
    override init() {
        super.init()
        hasThousandSeparators = false
        if T.self == Float.self {
            maximumSignificantDigits = 7
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func string(for obj: Any?) -> String? {
        if let number = obj as? NSNumber {
            // Use scientific notation for very large or very small values
            let val = abs(number.doubleValue)
            let useScientific = val >= 1_000_000 || (val > 0 && val < 0.001)
            numberStyle = useScientific ? .scientific : .decimal
        }
        return super.string(for: obj)
    }

    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        guard let value = T(string) else {
            error?.pointee = "The value must be a floating point number." as NSString
            return false
        }
        obj?.pointee = Double(value) as NSNumber
        return true
    }
}
