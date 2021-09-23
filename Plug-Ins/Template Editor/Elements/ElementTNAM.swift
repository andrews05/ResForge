import Foundation
import RFSupport

class ElementTNAM: ComboElement {
    private var tValue: FourCharCode = 0
    // This is marked as dynamic so that RSID can bind to it and receive changes
    @objc dynamic private var value: String {
        get { tValue.stringValue }
        set { tValue = FourCharCode(newValue) }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        value = value // Trigger bindings
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override class var formatter: Formatter? {
        let formatter = MacRomanFormatter()
        formatter.stringLength = 4
        formatter.exactLengthRequired = true
        return formatter
    }
}
