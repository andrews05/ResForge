import Cocoa
import RFSupport

class ElementRECT: Element {
    @objc private var top: Int16 = 0
    @objc private var left: Int16 = 0
    @objc private var bottom: Int16 = 0
    @objc private var right: Int16 = 0
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        let values = meta.components(separatedBy: ",")
        if values.count == 4 {
            top = Int16(values[0]) ?? top
            left = Int16(values[1]) ?? left
            bottom = Int16(values[2]) ?? bottom
            right = Int16(values[3]) ?? right
        }
    }
    
    override func configure() throws {
        self.width = 240
    }
    
    override func configure(view: NSView) {
        Self.configure(fields: ["top", "left", "bottom", "right"], in: view, for: self)
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        top = try reader.read()
        left = try reader.read()
        bottom = try reader.read()
        right = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(top)
        writer.write(left)
        writer.write(bottom)
        writer.write(right)
    }
    
    static func configure(fields: [String], in view: NSView, for element: Element) {
        var frame = view.frame
        let width = element.width / CGFloat(fields.count)
        frame.size.width = width - 4
        for key in fields {
            let field = NSTextField(frame: frame)
            field.placeholderString = key
            field.formatter = element.formatter
            field.delegate = element
            field.bind(.value, to: element, withKeyPath: key, options: nil)
            view.addSubview(field)
            frame.origin.x += width
        }
    }
    
    override class var formatter: Formatter? {
        return ElementDBYT<Int16>.formatter
    }
}
