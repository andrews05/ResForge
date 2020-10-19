import Cocoa
import RKSupport

// Abstract Element subclass that handles keyed sections
class KeyableElement: CaseableElement {
    @objc private let isKeyed: Bool
    private var observingValue = true
    private var keyedSections: [ElementCASE: ElementKEYB]!
    private var currentSection: ElementKEYB!
    
    required init(type: String, label: String, tooltip: String? = nil) {
        isKeyed = type.first == "K"
        super.init(type: type, label: label, tooltip: tooltip)
        if isKeyed {
            self.width = 240
        }
    }
    
    override func configure() throws {
        if !isKeyed {
            try super.configure()
            return
        }
        
        try self.readCases()
        
        // Set initial value to first case
        let caseEl = self.cases.first! as! ElementCASE
        currentSection = keyedSections[caseEl]
        var value = caseEl.value as AnyObject?
        try self.validateValue(&value)
        self.setValue(value, forKey: "value")
        self.parentList.insert(currentSection)
        
        // Use KVO to observe value change when data is first read
        // This saves us adding any key logic to the concrete element subclasses
        // NOTE: The "value" property of the concrete subclass must be "@objc dynamic"!
        self.addObserver(self, forKeyPath: "value", options: [], context: nil)
    }
    
    func readCases() throws {
        keyedSections = [:]
        // Read CASEs
        while let caseEl = self.parentList.peek(1) as? ElementCASE {
            _ = self.parentList.pop()
            self.cases.append(caseEl)
            self.caseMap[caseEl.value] = caseEl
        }
        if self.cases.count == 0 {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No 'CASE' elements found.", comment: ""))
        }
        // Read KEYBs
        while let keyB = self.parentList.peek(1) as? ElementKEYB {
            _ = self.parentList.pop()
            keyB.parentList = self.parentList
            try keyB.configure()
            // Allow one KEYB to be used for multiple CASEs
            let vals = keyB.label.components(separatedBy: ",")
            for value in vals {
                guard let caseEl = self.caseMap[value] as? ElementCASE else {
                    throw TemplateError.invalidStructure(keyB, NSLocalizedString("No corresponding 'CASE' element.", comment: ""))
                }
                keyedSections[caseEl] = keyB
            }
        }
        for caseEl in self.cases as! [ElementCASE] where keyedSections[caseEl] == nil {
            throw TemplateError.invalidStructure(caseEl, NSLocalizedString("No corresponding 'KEYB' element.", comment: ""))
        }
    }
    
    override func configure(view: NSView) {
        if !isKeyed {
            super.configure(view: view)
            return
        }
        
        var frame = view.frame
        frame.size.width = self.width-1
        frame.size.height = 23
        frame.origin.y = -1
        let keySelect = NSPopUpButton(frame: frame)
        keySelect.target = self
        keySelect.action = #selector(keyChanged(_:))
        keySelect.bind(NSBindingName("content"), to: self, withKeyPath: "cases", options: nil)
        keySelect.bind(NSBindingName("selectedObject"), to: self, withKeyPath: "value",
                       options: [.valueTransformer: self, .validatesImmediately: self.formatter != nil])
        view.addSubview(keySelect)
        if observingValue {
            // Remove the observer now if it hasn't been triggered already
            self.removeObserver(self, forKeyPath: "value")
            observingValue = false
        }
    }
    
    @IBAction func keyChanged(_ sender: NSPopUpButton) {
        let oldSection = self.setCase(cases[sender.indexOfSelectedItem] as? ElementCASE)
        if oldSection != currentSection {
            if let oldSection = oldSection {
                // Check if the section sizes match and attempt to copy the data
                var currentSize = 0
                oldSection.subElements.dataSize(&currentSize)
                var newSize = 0
                currentSection.subElements.dataSize(&newSize)
                if currentSize == newSize {
                    let writer = BinaryDataWriter(capacity: currentSize)
                    oldSection.writeData(to: writer)
                    let reader = BinaryDataReader(writer.data)
                    try? currentSection.readData(from: reader)
                }
            }
            // Reload the view - note the outline item isn't necessarily self
            let outline = self.parentList.controller.dataList!
            outline.reloadItem(outline.item(atRow: outline.row(for: sender)), reloadChildren: true)
        }
        self.parentList.controller.itemValueUpdated(sender)
    }
    
    private func setCase(_ element: ElementCASE?) -> ElementKEYB? {
        let newSection = element == nil ? nil : keyedSections[element!]!
        if newSection == currentSection {
            return currentSection
        }
        let oldSection = currentSection
        if let oldSection = oldSection {
            self.parentList.remove(oldSection)
        }
        currentSection = newSection
        if let newSection = newSection {
            self.parentList.insert(newSection, after: self)
        }
        return oldSection
    }
    
    override var hasSubElements: Bool {
        return isKeyed
    }
    
    override var subElementCount: Int {
        return currentSection?.subElementCount ?? 0
    }
    
    override func subElement(at index: Int) -> Element {
        return currentSection.subElement(at: index)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        // In theory this will only run when the key is first read from the resource
        // Make sure we load the correct section here so that we continue reading the resource into that section
        // If the value doesn't match a case the current section will be set to nil
        _ = self.setCase(self.transformedValue(self.value(forKey: "value")) as? ElementCASE)
        self.removeObserver(self, forKeyPath: "value")
        observingValue = false
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        if !isKeyed {
            return super.reverseTransformedValue(value)
        }
        // Value is a CASE element - get the string value
        return (value as! ElementCASE).value
    }
}
