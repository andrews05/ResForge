import Cocoa
import RKSupport

class ElementPNT: Element {
    @objc private var x: Int16 = 0
    @objc private var y: Int16 = 0
    
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
