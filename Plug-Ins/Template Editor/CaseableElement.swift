import Cocoa

// Abstract Element subclass that handles CASE elements
class CaseableElement: Element, NSComboBoxDelegate, NSComboBoxDataSource {
    var cases: [ElementCASE]!
    var caseMap: [AnyHashable: String]!
    
    override func configure() throws {
        // Read CASE elements
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            if cases == nil {
                cases = []
                caseMap = [:]
                self.width = 240
            }
            try caseEl.configure(for: self)
            guard caseMap[caseEl.value] == nil else {
                throw TemplateError.invalidStructure(caseEl, NSLocalizedString("Duplicate value.", comment: ""))
            }
            cases.append(caseEl)
            if caseEl.displayLabel == caseEl.displayValue {
                // Value matches title, use as-is
                caseMap[caseEl.value] = caseEl.displayValue
            } else {
                // Cases will show as "title = value" in the options list to allow searching by title
                // Text field will display as "value = title" for consistency when there's no matching case
                caseMap[caseEl.value] = "\(caseEl.displayValue) = \(caseEl.displayLabel)"
                caseEl.displayValue = "\(caseEl.displayLabel) = \(caseEl.displayValue)"
            }
        }
    }
    
    override func configure(view: NSView) {
        if cases == nil {
            super.configure(view: view)
            return
        }
        
        var frame = view.frame
        if self.width != 0 {
            frame.size.width = self.width - 1
        }
        frame.size.height = 26
        frame.origin.y -= 2
        let combo = NSComboBox(frame: frame)
        combo.isEditable = true
        combo.completes = true
        combo.numberOfVisibleItems = 10
        combo.delegate = self
        combo.placeholderString = self.type
        combo.usesDataSource = true
        combo.dataSource = self
        // The formatter isn't directly compatible with the values displayed by the combo box
        // Use a combination of value transformation with immediate validation to run the formatter manually
        combo.bind(.value, to: self, withKeyPath: "value", options: [.valueTransformer: self, .validatesImmediately: self.formatter != nil])
        view.addSubview(combo)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return caseMap[value as! AnyHashable] ?? self.formatter?.string(for: value) ?? value
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        // Don't use the formatter here as we can't handle the error
        return (value as? String)?.components(separatedBy: " = ").last ?? ""
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
