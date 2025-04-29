import AppKit
import RFSupport

class ElementRECT: BaseElement {
    static let formatter = IntFormatter<Int16>()
    @objc private var top: Int16 = 0
    @objc private var left: Int16 = 0
    @objc private var bottom: Int16 = 0
    @objc private var right: Int16 = 0

    override func configure() throws {
        width = 240
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

    static func configure(fields: [String], in view: NSView, for element: BaseElement) {
        var frame = view.frame
        let width = element.width / CGFloat(fields.count)
        frame.size.width = width - 4
        for key in fields {
            let field = NSTextField(frame: frame)
            field.placeholderString = key
            field.formatter = Self.formatter
            field.delegate = element
            field.bind(.value, to: element, withKeyPath: key)
            view.addSubview(field)
            frame.origin.x += width
        }
    }
}
