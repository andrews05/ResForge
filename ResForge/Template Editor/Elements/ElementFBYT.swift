import RFSupport

// Implements FBYT, FWRD, FLNG, Fnnn
class ElementFBYT: BaseElement {
    let length: Int
    var intValue: (any FixedWidthInteger)?

    required init(type: String, label: String) {
        switch type {
        case "FBYT":
            length = 1
        case "FWRD":
            length = 2
        case "FLNG":
            length = 4
        default:
            length = BaseElement.variableTypeValue(type)
        }
        super.init(type: type, label: label)
        visible = false
    }

    override func configure() {
        guard let metaValue else {
            return
        }

        if metaValue.starts(with: "0x") {
            let value = metaValue.dropFirst(2)
            switch length {
            case 1:
                intValue = UInt8(value, radix: 16)
            case 2:
                intValue = UInt16(value, radix: 16)
            case 4:
                intValue = UInt32(value, radix: 16)
            case 8:
                intValue = UInt64(value, radix: 16)
            default:
                break
            }
        } else {
            switch length {
            case 1:
                intValue = Int8(metaValue)
            case 2:
                intValue = Int16(metaValue)
            case 4:
                intValue = Int32(metaValue)
            case 8:
                intValue = Int64(metaValue)
            default:
                break
            }
        }
    }

    override func readData(from reader: BinaryDataReader) throws {
        try reader.advance(length)
    }

    override func writeData(to writer: BinaryDataWriter) {
        if let intValue {
            assert(intValue.bitWidth / 8 == length)
            writer.write(intValue)
        } else {
            writer.advance(length)
        }
    }
}
