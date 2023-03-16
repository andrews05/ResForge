import Cocoa
import RFSupport

// Implements BB08, WB16, LB32, QB64
// These types would otherwise be equivalent to UBYT etc so we do a special case here to instead display a grid of checkboxes.
// The meta value may be either a default value or an id reference to STR# resource containing names for each bit (e.g. "#128")
class ElementBB08<T: FixedWidthInteger & UnsignedInteger>: CasedElement {
    @objc private var value: UInt = 0 {
        didSet {
            // The field is not bound to the value so we need to update it manually
            valueField?.objectValue = value
            // Keep a copy of the formatted value in the placeholder string so it can be restored when necessary
            valueField?.placeholderString = valueField?.stringValue
            // Always restore the colour
            valueField?.textColor = .labelColor
        }
    }
    weak var valueField: NSTextField?
    weak var checkboxes: NSView?
    private var bitNames: [String] = []

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        width = 180
        rowHeight = Double(T.bitWidth/8 * 20) + 21
    }

    override func configure() throws {
        // Cases not actually supported but we still want to allow default values
        _ = self.defaultValue()
        
        // Check for an id reference and try to load names from a STR#
        var listID = 0
        if let metaValue,
           case let scanner = Scanner(string: metaValue),
           scanner.scanString("#", into: nil),
           scanner.scanInt(&listID),
           let list = parentList.controller.manager.findResource(type: ResourceType("STR#"), id: listID, currentDocumentOnly: false) {
            let reader = BinaryDataReader(list.data)
            do {
                try reader.advance(2)
                for _ in 0..<T.bitWidth {
                    bitNames.append(try reader.readPString())
                }
            } catch {}
        }
    }

    override func configure(view: NSView) {
        // Create hex representation
        var frame = view.frame
        frame.origin.y += 4
        frame.size.width = 134
        frame.size.height = 14
        let valueField = NSTextField(labelWithString: "")
        valueField.frame = frame
        valueField.font = NSFont.userFixedPitchFont(ofSize: 12)
        valueField.formatter = formatter
        valueField.objectValue = value
        valueField.placeholderString = valueField.stringValue
        view.addSubview(valueField)
        self.valueField = valueField

        // Create bit number view, shown on hover of a checkbox
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
        valueField.menu = actionButton.menu

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
            checkbox.numberField = bitNum
            checkbox.labelField = valueField
            checkbox.actionButton = actionButton
            checkbox.frame = frame
            checkbox.tag = i
            if i < bitNames.endIndex {
                checkbox.title = bitNames[i]
            }
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
        let paste = NSMenuItem(title: NSLocalizedString("Paste", comment: ""), action: #selector(self.paste(_:)), keyEquivalent: "")
        let pasteCombine = NSMenuItem(title: NSLocalizedString("Paste and Merge", comment: ""), action: #selector(self.pasteAndMerge(_:)), keyEquivalent: "")
        let clear = NSMenuItem(title: NSLocalizedString("Clear", comment: ""), action: #selector(self.clear(_:)), keyEquivalent: "")
        copy.target = self
        paste.target = self
        pasteCombine.target = self
        clear.target = self
        let actions = NSMenu()
        actions.items = [copy, paste, pasteCombine, clear]
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
        let location = NSPoint(x: sender.frame.minX, y: sender.frame.maxY + 6)
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

    // Clear all bits
    @IBAction private func clear(_ sender: Any) {
        self.setValue(0)
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

// NSButton subclass that shows info about the bit on hover
class BitButton: NSButton {
    weak var numberField: NSTextField?
    weak var actionButton: NSButton?
    weak var labelField: NSTextField?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        self.addTrackingArea(tracking)
    }

    override func mouseEntered(with event: NSEvent) {
        // Show the bit number in place of the action button
        numberField?.integerValue = tag + 1
        actionButton?.isHidden = true
        // The label field will show the name of the bit if we have one, else the formatted value
        labelField?.objectValue = title.isEmpty ? 1 << tag : title
        labelField?.textColor = .secondaryLabelColor
    }

    override func mouseExited(with event: NSEvent) {
        // In case we hovered onto an adjacent bit, prevent flicker by deferring the action
        // Then we can tell if we need to restore the view by checking if the bit number still matches
        DispatchQueue.main.async { [self] in
            if numberField?.integerValue == tag + 1 {
                numberField?.stringValue = ""
                actionButton?.isHidden = false
                labelField?.objectValue = labelField?.placeholderString
                labelField?.textColor = .labelColor
            }
        }
    }
}
