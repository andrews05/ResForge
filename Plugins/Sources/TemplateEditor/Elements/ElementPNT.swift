import AppKit
import RFSupport

// QuickDraw point stores a vertical and horizontal co-ordinate, opposite of typical x,y points
class ElementPNT: BaseElement {
    @objc private var v: Int16 = 0
    @objc private var h: Int16 = 0

    override func configure() throws {
        blockWidth = 4
    }

    override func configure(view: NSView) {
        ElementRECT.configure(fields: ["v", "h"], in: view, for: self)
    }

    override func readData(from reader: BinaryDataReader) throws {
        v = try reader.read()
        h = try reader.read()
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(v)
        writer.write(h)
    }
}
