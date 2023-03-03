import Cocoa
import RFSupport

// Implements BB08, WB16, LB32, QB64
// These types would otherwise be equivalent to UBYT etc so we do a special case here to instead display a grid of checkboxes.
class ElementBB08<T: FixedWidthInteger & UnsignedInteger>: CasedElement {
    @objc dynamic private var value: UInt = 0
    weak var checkboxes: NSView?
    
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
        textField.isSelectable = true
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
        
        // Create action button
        frame.origin.x = view.frame.origin.x + 142
        frame.size.width = 14
        let actionButton = self.createActionButton(at: frame)
        view.addSubview(actionButton)
        
        // Create checkboxes holder
        // This allows us to keep a weak reference to the collection
        frame.origin.x = view.frame.origin.x
        frame.origin.y += 15
        frame.size.width = 20 * 8
        frame.size.height = 20 * CGFloat(T.bitWidth / 8)
        let checkboxes = NSView(frame: frame)
        view.addSubview(checkboxes)
        self.checkboxes = checkboxes
        
        // Create checkboxes
        frame.origin.x = 0
        frame.origin.y = frame.height - 20
        frame.size.width = 20
        frame.size.height = 20
        for i in 0..<T.bitWidth {
            // We can't easily bind all the checkboxes, so just use the action to update
            let checkbox = BitButton(checkboxWithTitle: "", target: self, action: #selector(self.toggleBit(_:)))
            checkbox.textField = bitNum
            checkbox.actionButton = actionButton
            checkbox.frame = frame
            checkbox.tag = i
            if value & (1 << i) != 0 {
                checkbox.state = .on
            }
            checkboxes.addSubview(checkbox)
            frame.origin.x += 20
            if i % 8 == 7 {
                frame.origin.x = 0
                frame.origin.y -= 20
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
    
    // MARK: - Action Button
    
    private func createActionButton(at frame: NSRect) -> NSButton {
        let copy = NSMenuItem(title: NSLocalizedString("Copy", comment: ""), action: #selector(self.copy(_:)), keyEquivalent: "")
        copy.target = self
        let paste = NSMenuItem(title: NSLocalizedString("Paste", comment: ""), action: #selector(self.paste(_:)), keyEquivalent: "")
        paste.target = self
        let pasteCombine = NSMenuItem(title: NSLocalizedString("Paste and Merge", comment: ""), action: #selector(self.pasteAndMerge(_:)), keyEquivalent: "")
        pasteCombine.target = self
        let actions = NSMenu()
        actions.items = [copy, paste, pasteCombine]
        let actionButton = NSButton(frame: frame)
        actionButton.isBordered = false
        actionButton.bezelStyle = .inline
        actionButton.image = NSImage(named: NSImage.actionTemplateName)
        actionButton.menu = actions
        actionButton.target = self
        actionButton.action = #selector(self.actionMenu(_:))
        return actionButton
    }
    
    @IBAction private func actionMenu(_ sender: NSButton) {
        guard let menu = sender.menu, let view = sender.superview else {
            return
        }
        let location = NSPoint(x: sender.frame.maxX - menu.size.width, y: sender.frame.maxY + 8)
        menu.popUp(positioning: nil, at: location, in: view)
    }
    
    // Copy the current value using the formatter
    @IBAction private func copy(_ sender: Any) {
        if let stringValue = formatter.string(for: value) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([stringValue as NSString])
        }
    }
    
    // Paste a new value
    @IBAction private func paste(_ sender: Any) {
        if let newValue = readValueFromPasteboard() {
            self.setValue(newValue)
        }
    }
    
    // Paste a new value using bitwise OR
    @IBAction private func pasteAndMerge(_ sender: Any) {
        if let newValue = readValueFromPasteboard() {
            self.setValue(value | newValue)
        }
    }
    
    private func readValueFromPasteboard() -> UInt? {
        guard let stringValue = NSPasteboard.general.readObjects(forClasses: [NSString.self])?.first as? String else {
            return nil
        }
        return try? formatter.getObjectValue(for: stringValue) as? UInt
    }
    
    private func setValue(_ newValue: UInt) {
        guard newValue != value else {
            return
        }
        value = newValue
        parentList.controller.itemValueUpdated(self)
        // Update the checkbox states
        if let checkboxes = checkboxes?.subviews as? [NSButton] {
            for checkbox in checkboxes {
                checkbox.state = value & (1 << checkbox.tag) == 0 ? .off : .on
            }
        }
    }
}

// NSButton subclass that shows tag number in an NSTextField on hover
class BitButton: NSButton {
    weak var textField: NSTextField?
    weak var actionButton: NSButton?

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
        actionButton?.isHidden = true
    }

    override func mouseExited(with event: NSEvent) {
        DispatchQueue.main.async { [self] in
            if let textField, textField.integerValue == tag + 1 {
                textField.stringValue = ""
                actionButton?.isHidden = false
            }
        }
    }
}
