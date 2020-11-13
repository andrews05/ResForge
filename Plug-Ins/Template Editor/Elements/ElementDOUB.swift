import RKSupport

class ElementDOUB: CaseableElement {
    @objc private var value: Double = 0
    
    override func configure() throws {
        self.width = 180
        try super.configure()
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = Double(bitPattern: try reader.read())
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.hasThousandSeparators = false
        formatter.numberStyle = .scientific
        formatter.minimum = 0
        formatter.maximum = Double.greatestFiniteMagnitude as NSNumber
        formatter.nilSymbol = "\0"
        return formatter
    }
}
