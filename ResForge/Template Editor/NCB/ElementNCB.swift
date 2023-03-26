import Cocoa

// The NCB element performs parsing of a Nova Control Bit string and displays the result in a popover
class ElementNCB: ElementCSTR {
    let expressionType: NCBExpression.Type

    required init(type: String, label: String) {
        // Determine test or set from label
        let isTest = label.uppercased().contains("TEST")
        expressionType = isTest ? NCBTestExpression.self : NCBSetExpression.self
        super.init(type: type, label: label)
    }

    override func configure(view: NSView) {
        super.configure(view: view)
        let textField = view.subviews.last as! NSTextField
        let type = expressionType == NCBTestExpression.self ? "Test" : "Set"
        textField.placeholderString = "NCB \(type) Expression (\(maxLength) characters)"

        // Overlay an info button on the right end of the field
        let infoButton = NSButton(frame: NSRect(x: textField.frame.maxX - 16, y: 7, width: 12, height: 12))
        infoButton.isBordered = false
        infoButton.bezelStyle = .inline
        if #available(macOS 11, *) {
            infoButton.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        } else {
            infoButton.image = NSImage(named: "NSToolbarGetInfo")
            infoButton.imageScaling = .scaleProportionallyDown
        }
        infoButton.target = self
        infoButton.action = #selector(showInfo(_:))
        view.addSubview(infoButton)
    }

    @objc private func showInfo(_ sender: NSButton) {
        if let control = sender.previousKeyView as? NSControl {
            self.showPopover(control)
        }
    }

    override func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSTextView.insertNewline(_:)) {
            self.showPopover(control)
            return true
        }
        return super.control(control, textView: textView, doCommandBy: commandSelector)
    }

    private func showPopover(_ control: NSControl) {
        // Commit the current value
        if let editor = control.currentEditor() {
            control.endEditing(editor)
        }

        let field = self.popoverTextField()

        // Calculate field dimensions, allowing 8px padding on all sides
        let width = max(control.frame.width - 16, field.intrinsicContentSize.width + 4)
        let height = field.intrinsicContentSize.height
        field.frame = NSRect(x: 8, y: 8, width: width, height: height)

        // Construct the view controller and popover
        let controller = NSViewController()
        controller.view = NSView(frame: NSRect(x: 0, y: 0, width: width + 16, height: height + 16))
        controller.view.addSubview(field)
        let popover = NCBPopover()
        popover.behavior = .transient
        popover.contentViewController = controller

        // Show the popover, preferring the bottom edge
        popover.show(relativeTo: .zero, of: control, preferredEdge: .maxY)
        // Make the popover the first responder so it will close and return to the control on any keypress
        control.window?.makeFirstResponder(popover)
    }

    private func popoverTextField() -> NSTextField {
        let field = NSTextField(labelWithString: "")
        if value.isEmpty {
            // When no value, show list of all operators
            field.stringValue = expressionType.usage
        } else {
            // Parse the value
            do {
                let parsed = try expressionType.parse(value.uppercased())
                field.stringValue = parsed.description(manager: parentList.controller.manager)
            } catch let err {
                // If multiple failures occur, only show the first one (index 1 after splitting)
                let errors = "\(err)".components(separatedBy: "\n\n")
                let message = errors.endIndex > 1 ? errors[1] : errors[0]
                // Filter out duplicate expectations
                var unique = Set<Substring>()
                field.stringValue = message.split(separator: "\n").filter {
                    unique.insert($0).inserted
                }.joined(separator: "\n")
                field.font = .userFixedPitchFont(ofSize: 12)
            }
        }
        return field
    }
}

// Custom popover subclass closes itself on any keypress
class NCBPopover: NSPopover {
    override func keyDown(with event: NSEvent) {
        self.close()
    }
}
