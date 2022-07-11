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
        frame.size.width = 134
        frame.size.height = 14
        let textField = NSTextField(labelWithString: "")
        textField.frame = frame
        textField.font = NSFont.userFixedPitchFont(ofSize: 12)
        textField.formatter = formatter
        textField.bind(.value, to: self, withKeyPath: "value")
        view.addSubview(textField)

        // Create bit number view
        frame.origin.x += 134
        frame.size.width = 24
        let bitNum = NSTextField(labelWithString: "")
        bitNum.frame = frame
        bitNum.font = NSFont.userFixedPitchFont(ofSize: 12)
        bitNum.alignment = .right
        bitNum.textColor = .secondaryLabelColor
        view.addSubview(bitNum)
        
        // Create checkboxes
        frame.origin.x = view.frame.origin.x
        frame.origin.y += 15
        frame.size.width = 20
        frame.size.height = 20
        for i in 0..<T.bitWidth {
            // We can't easily bind all the checkboxes, so just use the action to update
            let checkbox = BitButton(checkboxWithTitle: "", target: self, action: #selector(self.toggleBit(_:)))
            checkbox.textField = bitNum
            checkbox.frame = frame
            checkbox.tag = i
            if (value & (1 << checkbox.tag)) != 0 {
                checkbox.state = .on
            }
            view.addSubview(checkbox)
            frame.origin.x += 20
            if i % 8 == 7 {
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

// NSButton subclass that shows tag number in an NSTextField on hover
class BitButton: NSButton {
    weak var textField: NSTextField?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        self.addTrackingArea(tracking)
    }

    override func mouseEntered(with event: NSEvent) {
        textField?.integerValue = tag + 1
    }

    override func mouseExited(with event: NSEvent) {
        textField?.stringValue = ""
    }
}
