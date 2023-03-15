import RFSupport

// Implements AWRD, ALNG, AL08, AL16
class ElementAWRD: Element {
    let alignment: Int

    required init(type: String, label: String) {
        switch type {
        case "AWRD":
            alignment = 2
        case "ALNG":
            alignment = 4
        default:
            alignment = Int(type.suffix(2))!
        }
        super.init(type: type, label: label)
        visible = false
    }

    private func align(_ pos: Int) -> Int {
        // Note: Swift % does not work as expected with negative values
        let m = pos % alignment
        return m == 0 ? 0 : alignment - m
    }

    override func readData(from reader: BinaryDataReader) throws {
        try reader.advance(self.align(reader.position))
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.advance(self.align(writer.data.count))
    }
}
