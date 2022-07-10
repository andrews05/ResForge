import Cocoa
import RFSupport

// Implements BB08, WB16, LB32, QB64
// These types would otherwise be equivalent to UBYT etc so we do a special case here to instead display a grid of checkboxes.
class ElementBB08<T: FixedWidthInteger & UnsignedInteger>: CasedElement {
    @objc dynamic private var value: UInt = 0
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        width = 180
        rowHeight = Double(T.bitWidth/8 * 20) + 21
    }
    
    override func configure() throws {
        // Cases not actually supported but we still want to allow default values
        _ = self.defaultValue()
    }
    
    override func configure(view: NSView) {
        // Create hex representation
        var frame = view.frame
        frame.origin.y += 4
        frame.size.height = 14
        let textField = NSTextField(frame: frame)
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.font = NSFont.userFixedPitchFont(ofSize: 12)
        textField.formatter = formatter
        textField.bind(.value, to: self, withKeyPath: "value")
        view.addSubview(textField)
        
        // Create checkboxes
        frame.origin.y += 15
        frame.size.width = 20
        frame.size.height = 20
        for i in 1...T.bitWidth {
            let checkbox = NSButton(frame: frame)
            checkbox.setButtonType(.switch)
            checkbox.bezelStyle = .regularSquare
            // We can't easily bind all the checkboxes, so just set the initial state and use the tag/action to update
            checkbox.tag = T.bitWidth - i
            checkbox.target = self
            checkbox.action = #selector(self.toggleBit(_:))
            if (value & (1 << checkbox.tag)) != 0 {
                checkbox.state = .on
            }
            view.addSubview(checkbox)
            frame.origin.x += 20
            if i % 8 == 0 {
                frame.origin.x = view.frame.origin.x
                frame.origin.y += 20
            }
        }
    }

    @IBAction private func toggleBit(_ sender: NSButton) {
        value ^= 1 << sender.tag
        parentList.controller.itemValueUpdated(sender)
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        value = UInt(try reader.read() as T)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(T(value))
    }
    
    override var formatter: Formatter {
        self.sharedFormatter("HEX\(T.bitWidth)") { HexFormatter<T>() }
    }
}
