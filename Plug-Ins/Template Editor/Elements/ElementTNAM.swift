import Foundation
import RFSupport

class ElementTNAM: CasedElement {
    private var tValue: FourCharCode = 0
    // This is marked as dynamic so that RSID can bind to it and receive changes
    @objc dynamic private var value: String {
        get { tValue.stringValue }
        set { tValue = FourCharCode(newValue) }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        value = String(value) // Trigger binding update
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    override var formatter: Formatter {
        self.sharedFormatter() { MacRomanFormatter(stringLength: 4, exactLengthRequired: true) }
    }
}
