import Cocoa

// Abstract Element subclass that handles CASE elements
class CaseableElement: Element, NSComboBoxDelegate {
    @objc var cases: [String]! = nil;
    var caseMap: [String: String]! = nil;
    
    override func configure() throws {
        // Read CASE elements
        if self.parentList.peek(1) is ElementCASE {
            cases = []
            caseMap = [:]
            self.width = 240
            while let element = self.parentList.peek(1) as? ElementCASE {
                _ = self.parentList.pop()
                // Cases will show as "name = value" in the options list to allow searching by name
                // Text field will display as "value = name" for consistency when there's no matching case
                let option = "\(element.displayLabel) = \(element.value)"
                let display = "\(element.value) = \(element.displayLabel)"
                cases.append(option)
                caseMap[element.value] = display
            }
        }
    }
    
    override func configure(view: NSView) {
        if self.caseMap == nil {
            super.configure(view: view)
            return
        }
        var frame = view.frame
        if self.width != 0 {
            frame.size.width = self.width - 1
        }
        frame.size.height = 26
        frame.origin.y = -2
        let combo = NSComboBox(frame: frame)
        // Use insensitive completion, except for TNAM
        if self.type != "TNAM" {
            combo.cell = InsensitiveComboBoxCell()
        }
        combo.isEditable = true
        combo.completes = true
        combo.numberOfVisibleItems = 10
        combo.delegate = self
        combo.placeholderString = self.type
        combo.bind(NSBindingName(rawValue: "contentValues"), to: self, withKeyPath: "cases", options: nil)
        // The formatter isn't directly compatible with the values displayed by the combo box
        // Use a combination of value transformation with immediate validation to run the formatter manually
        combo.bind(NSBindingName(rawValue: "value"), to: self, withKeyPath: "value", options:
                    [.valueTransformer: self, .validatesImmediately: self.formatter != nil])
        view.addSubview(combo)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        // Run the value through the formatter before looking it up in the map
        var v = value
        if let f = self.formatter {
            v = f.string(for: value)
        }
        return caseMap[v as! String] ?? v
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        // Don't use the formatter here as we can't handle the error
        return (value as! String).components(separatedBy: " = ").last
    }
    
    // This is a key-value validation function for the specific key of "value"
    @objc func validateValue(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // Here we validate the value with the formatter and can raise an error
        var errorString: NSString? = nil
        self.formatter?.getObjectValue(ioValue, for: ioValue.pointee as! String, errorDescription: &errorString)
        if let errorString = errorString {
            throw NSError(domain: NSCocoaErrorDomain, code: NSKeyValueValidationError, userInfo: [NSLocalizedDescriptionKey: errorString])
        }
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        // Notify the controller that the value changed
        self.parentList.controller.itemValueUpdated(notification.object!)
    }
}


class InsensitiveComboBoxCell: NSComboBoxCell, NSTableViewDelegate {
    var rightMargin: CGFloat = 0
    
    override func completedString(_ string: String) -> String? {
        return (self.objectValues as? [String])?.first {
            $0.commonPrefix(with: string, options: .caseInsensitive).count == string.count
        }
    }
    
    // Changing the NSComboBox's cell breaks the notification bindings so we need to post them manually
    func tableViewSelectionDidChange(_ notification: Notification) {
        NotificationCenter.default.post(name: NSComboBox.selectionDidChangeNotification, object: self.controlView)
    }
    
    // Right margin is set by RSID to allow space for link button
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var r = super.drawingRect(forBounds: rect)
        r.size.width -= rightMargin
        return r
    }
}
