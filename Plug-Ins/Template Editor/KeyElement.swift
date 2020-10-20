import Cocoa
import RKSupport

class KeyElement: Element {
    @objc private var cases: [ElementCASE] = []
    private var caseMap: [AnyHashable: ElementCASE] = [:]
    private var keyedSections: [ElementCASE: ElementKEYB]!
    private var currentSection: ElementKEYB!
    
    override func configure() throws {
        try self.readCases()
        self.width = 240
        
        // Set initial value to first case
        let caseEl = self.cases.first!
        currentSection = keyedSections[caseEl]
        self.setValue(caseEl.objectValue, forKey: "value")
        self.parentList.insert(currentSection)
    }
    
    private func readCases() throws {
        keyedSections = [:]
        // Read CASEs
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            try caseEl.configure(for: self)
            self.cases.append(caseEl)
            self.caseMap[caseEl.objectValue as! AnyHashable] = caseEl
        }
        if self.cases.isEmpty {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ elements found.", comment: ""))
        }
        // Read KEYBs
        while let keyB = self.parentList.pop("KEYB") as? ElementKEYB {
            keyB.parentList = self.parentList
            try keyB.configure()
            // Allow one KEYB to be used for multiple CASEs
            let vals = keyB.label.components(separatedBy: ",")
            for value in vals {
                guard let caseEl = self.cases.first(where: { $0.value == value }) else {
                    throw TemplateError.invalidStructure(keyB, NSLocalizedString("No corresponding ‘CASE’ element.", comment: ""))
                }
                keyedSections[caseEl] = keyB
            }
        }
        for caseEl in self.cases where keyedSections[caseEl] == nil {
            throw TemplateError.invalidStructure(caseEl, NSLocalizedString("No corresponding ‘KEYB’ element.", comment: ""))
        }
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.size.width = self.width-1
        frame.size.height = 23
        frame.origin.y = -1
        let keySelect = NSPopUpButton(frame: frame)
        keySelect.target = self
        keySelect.action = #selector(keyChanged(_:))
        keySelect.bind(NSBindingName("content"), to: self, withKeyPath: "cases", options: nil)
        keySelect.bind(NSBindingName("selectedObject"), to: self, withKeyPath: "value", options: [.valueTransformer: self])
        view.addSubview(keySelect)
    }
    
    @IBAction func keyChanged(_ sender: NSPopUpButton) {
        let oldSection = self.setCase(cases[sender.indexOfSelectedItem])
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
    
    func setCase(_ element: ElementCASE?) -> ElementKEYB? {
        let newSection = element.map { keyedSections[$0]! }
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
        return true
    }
    
    override var subElementCount: Int {
        return currentSection?.subElementCount ?? 0
    }
    
    override func subElement(at index: Int) -> Element {
        return currentSection.subElement(at: index)
    }
    
    
    override func transformedValue(_ value: Any?) -> Any? {
        return caseMap[value as! AnyHashable] ?? value
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return (value as! ElementCASE).objectValue
    }
}
