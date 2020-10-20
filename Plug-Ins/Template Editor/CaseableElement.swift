import Cocoa

// Abstract Element subclass that handles CASE elements
class CaseableElement: Element, NSComboBoxDelegate, NSComboBoxDataSource {
    var cases: [String]!
    var caseMap: [String: String]!
    
    override func configure() throws {
        // Read CASE elements
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            if cases == nil {
                cases = []
                caseMap = [:]
                self.width = 240
            }
            cases.append(caseEl.optionLabel)
            caseMap[caseEl.value] = caseEl.displayLabel
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
        frame.origin.y = -2
        let combo = NSComboBox(frame: frame)
        combo.isEditable = true
        combo.completes = true
        combo.numberOfVisibleItems = 10
        combo.delegate = self
        combo.placeholderString = self.type
//        combo.bind(NSBindingName(rawValue: "contentValues"), to: self, withKeyPath: "cases", options: nil)
        combo.usesDataSource = true
        combo.dataSource = self
        // The formatter isn't directly compatible with the values displayed by the combo box
        // Use a combination of value transformation with immediate validation to run the formatter manually
        combo.bind(NSBindingName(rawValue: "value"), to: self, withKeyPath: "value", options:
                    [.valueTransformer: self, .validatesImmediately: self.formatter != nil])
        view.addSubview(combo)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        // Run the value through the formatter before looking it up in the map
        let value = self.formatter?.string(for: value) ?? value
        return caseMap[value as! String] ?? value
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
            $0.commonPrefix(with: string, options: options).count == string.count
        }
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return index < self.cases.endIndex ? self.cases[index] : nil
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return self.cases.count
    }
}
