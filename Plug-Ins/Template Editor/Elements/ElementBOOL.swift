import Cocoa
import RKSupport

class ElementBOOL: Element {
    @objc private var value: UInt8 = 0
    
    override func configure(view: NSView) {
        view.addSubview(Self.createCheckbox(with: view.frame, for: self))
    }
    
    static func createCheckbox(with frame: NSRect, for element: Element) -> NSButton {
        let checkbox = NSButton(frame: frame)
        checkbox.setButtonType(.switch)
        checkbox.bezelStyle = .regularSquare
        // Use the second part of the label as the checkbox title
        let split = element.label.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        checkbox.title = split.count == 2 ? String(split[1]) : "\0"
        checkbox.action = #selector(TemplateWindowController.itemValueUpdated(_:))
        checkbox.bind(.value, to: element, withKeyPath: "value", options: nil)
        if frame.size.width > 20 {
            checkbox.autoresizingMask = .width
        }
        return checkbox
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = try reader.read()
        try reader.advance(1)
    }
    
    override func dataSize(_ size: inout Int) {
        size += 2
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value)
        writer.advance(1)
    }
}
