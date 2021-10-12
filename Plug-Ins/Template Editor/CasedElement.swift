import Cocoa
import OrderedCollections

// Abstract Element subclass for fields with associated CASE elements
class CasedElement: Element, FormattedElement, NSComboBoxDelegate, NSComboBoxDataSource {
    var cases: OrderedDictionary<AnyHashable, ElementCASE> = [:]
    
    override func configure() throws {
        try self.readCases()
        _ = self.defaultValue()
        if !cases.isEmpty {
            self.width = 240
        }
        for caseEl in cases.values where caseEl.displayLabel != caseEl.displayValue {
            // Cases will show as "title = value" in the options list to allow searching by title
            // Text field will display as "value = title" for consistency when there's no matching case
            let displayValue = caseEl.displayValue
            caseEl.metaValue = "\(caseEl.displayLabel) = \(displayValue)"
            caseEl.displayLabel = "\(displayValue) = \(caseEl.displayLabel)"
        }
    }
    
    override func configure(view: NSView) {
        if cases.isEmpty {
            self.configureTextField(view: view)
        } else {
            self.configureComboBox(view: view)
        }
    }
    
    // All subclasses must provide a formatter to format case values.
    // We can't enforce this easily so we just have a default implementation which triggers a fatal error.
    var formatter: Formatter {
        fatalError("Formatter not implemented.")
    }
    
    func defaultValue() -> AnyHashable? {
        // Attempt to get a default value from the first case or the meta value
        if let value = cases.keys.first ?? self.parseMetaValue()  {
            self.setValue(value, forKey: "value")
            return value
        }
        return self.value(forKey: "value") as? AnyHashable
    }
    
    private func parseMetaValue() -> AnyHashable? {
        if let metaValue = metaValue {
            return try? formatter.getObjectValue(for: metaValue) as? AnyHashable
        }
        return nil
    }
    
    func readCases() throws {
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            try caseEl.configure(for: self)
            guard cases[caseEl.value] == nil else {
                throw TemplateError.invalidStructure(caseEl, NSLocalizedString("Duplicate value.", comment: ""))
            }
            cases[caseEl.value] = caseEl
        }
    }
    
    func configureTextField(view: NSView) {
        var frame = view.frame
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
    }
    
    func configureComboBox(view: NSView) {
        var frame = view.frame
        if width != 0 {
            frame.size.width = width - 1
        }
        frame.size.height = 24
        frame.origin.y -= 1
        let combo = NSComboBox(frame: frame)
        combo.completes = true
        combo.numberOfVisibleItems = 10
        combo.delegate = self
        combo.placeholderString = type
        combo.usesDataSource = true
        combo.dataSource = self
        // The formatter isn't directly compatible with the values displayed by the combo box
        // Use a combination of value transformation with immediate validation to run the formatter manually
        combo.bind(.value, to: self, withKeyPath: "value", options: [.valueTransformer: self, .validatesImmediately: true])
        view.addSubview(combo)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return cases[value as! AnyHashable]?.displayLabel ?? self.formatter.string(for: value) ?? value
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        // Don't use the formatter here as we can't handle the error
        return (value as? String)?.components(separatedBy: " = ").last ?? ""
    }
    
    // This is a key-value validation function for the specific key of "value"
    @objc func validateValue(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        // Here we validate the value with the formatter and can raise an error
        ioValue.pointee = try formatter.getObjectValue(for: ioValue.pointee as! String)
    }
    
    // MARK: - Combo box functions
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        // Notify the controller that the value changed
        self.parentList.controller.itemValueUpdated(notification.object!)
    }
    
    func comboBox(_ comboBox: NSComboBox, completedString string: String) -> String? {
        // Use insensitive completion, except for TNAM
        let options: NSString.CompareOptions = self.type == "TNAM" ? [] : .caseInsensitive
        return cases.values.first {
            $0.displayValue.commonPrefix(with: string, options: options).count == string.count
        }?.displayValue
    }
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        return index < cases.values.endIndex ? cases.values[index].displayValue : nil
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        return cases.count
    }
}
