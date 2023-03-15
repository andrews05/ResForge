import Foundation
import RFSupport

// Implements DBYT, DWRD, DLNG, DQWD, UBYT, UWRD, ULNG, UQWD
class ElementDBYT<T: FixedWidthInteger>: RangedElement {
    var tValue: T = 0
    @objc private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        switch T.bitWidth/8 {
        case 4:
            width = 90
        case 8:
            width = 150
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
        return self.sharedFormatter("\(key)\(T.bitWidth)") { IntFormatter<T>() }
    }
}

class IntFormatter<T: FixedWidthInteger>: NumberFormatter {
    override init() {
        super.init()
        minimum = T.min as? NSNumber
        maximum = T.max as? NSNumber
        allowsFloats = false
        nilSymbol = "\0"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
