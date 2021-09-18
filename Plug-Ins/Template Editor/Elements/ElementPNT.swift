import Cocoa
import RFSupport

class ElementPNT: Element {
    @objc private var x: Int16 = 0
    @objc private var y: Int16 = 0
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        let values = meta.components(separatedBy: ",")
        if values.count == 2 {
            x = Int16(values[0]) ?? x
            y = Int16(values[1]) ?? y
        }
    }
    
    override func configure() throws {
        self.width = 120
    }
    
    override func configure(view: NSView) {
        ElementRECT.configure(fields: ["x", "y"], in: view, for: self)
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        x = try reader.read()
        y = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(x)
        writer.write(y)
    }
    
    override class var formatter: Formatter? {
        return ElementDBYT<Int16>.formatter
    }
}
