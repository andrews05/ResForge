import RFSupport

// Implements FBYT, FWRD, FLNG, Fnnn
class ElementFBYT: BaseElement {
    let length: Int
    var bytes: Data?

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
        // If the metaValue contains hex bytes we will use this for the filler
        guard let metaValue, metaValue.starts(with: "0x") else {
            return
        }
        bytes = metaValue.dropFirst(2).data(using: .hexadecimal)?.prefix(length)
    }

    override func readData(from reader: BinaryDataReader) throws {
        try reader.advance(length)
    }

    override func writeData(to writer: BinaryDataWriter) {
        if let bytes {
            writer.writeData(bytes)
            writer.advance(length - bytes.count)
        } else {
            writer.advance(length)
        }
    }
}
