import Cocoa

// Abstract Element subclass for basic TextFields or ComboBoxes
class ComboElement: CasedElement, NSComboBoxDelegate, NSComboBoxDataSource {
    required init!(type: String, label: String) {
        super.init(type: type, label: label)
        // Attempt to set a default value from the meta value
        if let metaValue = metaValue, let value = try? formatter?.getObjectValue(for: metaValue) {
            self.setValue(value, forKey: "value")
        }
    }
    
    override func configure() throws {
        // Read CASE elements
        while let caseEl = self.nextCase() {
            if cases == nil {
                cases = []
                self.width = 240
            }
            try caseEl.configure(for: self)
            guard caseMap[caseEl.value] == nil else {
                throw TemplateError.invalidStructure(caseEl, NSLocalizedString("Duplicate value.", comment: ""))
            }
            if caseEl.displayLabel != caseEl.displayValue {
                // Cases will show as "title = value" in the options list to allow searching by title
                // Text field will display as "value = title" for consistency when there's no matching case
                let displayValue = caseEl.displayValue
                caseEl.metaValue = "\(caseEl.displayLabel) = \(displayValue)"
                caseEl.displayLabel = "\(displayValue) = \(caseEl.displayLabel)"
            }
            cases.append(caseEl)
            caseMap[caseEl.value] = caseEl
        }
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        if cases == nil {
            // Standard text field
            frame.size.height = CGFloat(rowHeight)
            if width != 0 {
                frame.size.width = width - 4
            }
            let textField = NSTextField(frame: frame)
            textField.formatter = formatter
            textField.delegate = self
            textField.placeholderString = type
            textField.lineBreakMode = .byTruncatingTail
            textField.allowsDefaultTighteningForTruncation = true
            textField.bind(.value, to: self, withKeyPath: "value")
            view.addSubview(textField)
        } else {
            // Combo box with CASE suggestions
            if width != 0 {
                frame.size.width = width - 1
            }
            frame.size.height = 26
            frame.origin.y -= 2
            let combo = NSComboBox(frame: frame)
            combo.completes = true
            combo.numberOfVisibleItems = 10
            combo.delegate = self
            combo.placeholderString = type
            combo.usesDataSource = true
            combo.dataSource = self
            // The formatter isn't directly compatible with the values displayed by the combo box
            // Use a combination of value transformation with immediate validation to run the formatter manually
            combo.bind(.value, to: self, withKeyPath: "value", options: [.valueTransformer: self, .validatesImmediately: formatter != nil])
            view.addSubview(combo)
        }
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return caseMap[value as! AnyHashable]?.displayLabel ?? self.formatter?.string(for: value) ?? value
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        // Don't use the formatter here as we can't handle the error
        return (value as? String)?.components(separatedBy: " = ").last ?? ""
    }
    
    // This is a key-value validation function for the specific key of "value"
    @objc func validateValue(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // Here we validate the value with the formatter and can raise an error
        ioValue.pointee = try formatter?.getObjectValue(for: ioValue.pointee as! String)
    }
    
    // MARK: - Combo box functions
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        // Notify the controller that the value changed
        self.parentList.controller.itemValueUpdated(notification.object!)
    }
    
    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        // Use insensitive completion, except for TNAM
        let options: NSString.CompareOptions = self.type == "TNAM" ? [] : .caseInsensitive
        return self.cases.first {
            $0.displayValue.commonPrefix(with: string, options: options).count == string.count
        }?.displayValue
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return index < self.cases.endIndex ? self.cases[index].displayValue : nil
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return self.cases.count
    }
}
