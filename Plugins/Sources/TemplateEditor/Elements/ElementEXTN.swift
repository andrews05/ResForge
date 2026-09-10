import Foundation
import RFSupport

class ElementEXTN: CasedElement {
    @objc private var value: Float80 = 0

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        blockWidth = 6
    }

    override func readData(from reader: BinaryDataReader) throws {
        var exponent:UInt16 = try reader.read()
        let significand:UInt64 = try reader.read()
        var sign:FloatingPointSign
        if exponent & 0x8000 == 0x8000 {
            sign = FloatingPointSign.minus
            exponent &= 0x7FFF
        } else {
            sign = FloatingPointSign.plus
        }
        value = Float80(sign: sign, exponentBitPattern: UInt(exponent), significandBitPattern: significand)
    }

    override func writeData(to writer: BinaryDataWriter) {
        var exponent = UInt16(value.exponentBitPattern)
        let significand:UInt64 = value.significandBitPattern
        if value.sign == FloatingPointSign.minus {
            exponent &= 0x8000
        }
        writer.write(exponent)
        writer.write(significand)
    }

    override var formatter: Formatter {
        self.sharedFormatter {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = false
            formatter.numberStyle = .scientific
            formatter.minimum = 0
            formatter.maximum = NSNumber(nonretainedObject: Float80.greatestFiniteMagnitude)
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
