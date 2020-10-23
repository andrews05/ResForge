import RKSupport

class ElementREAL: CaseableElement {
    @objc private var value: Float = 0
    
    override func configure() throws {
        self.width = 90
        try super.configure()
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = Float(bitPattern: try reader.read())
    }
    
    override func dataSize(_ size: inout Int) {
        size += 4
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value.bitPattern)
    }
    
    override class var formatter: Formatter? {
        let formatter = NumberFormatter()
        formatter.hasThousandSeparators = false
        formatter.numberStyle = .scientific
        formatter.maximumSignificantDigits = 7
        formatter.minimum = 0
        formatter.maximum = Float.greatestFiniteMagnitude as NSNumber
        formatter.nilSymbol = "\0"
        return formatter
    }
}
