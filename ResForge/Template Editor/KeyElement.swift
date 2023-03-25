import Cocoa
import RFSupport

// Abstract Element subclass that handles key elements
class KeyElement: CasedElement, CollectionElement {
    // KeyElement acts as a proxy CollectionElement for KEYB - it does not actually have an endType but requires this for conformance.
    let endType = ""
    private var keyedSections: [AnyHashable?: ElementKEYB] = [:]
    var currentSection: ElementKEYB!
    @objc private var caseList: [ElementCASE] {
        cases.values.elements
    }

    override func configure() throws {
        try self.readSections()
        width = 240

        // Set initial state
        if let value = self.defaultValue(), let section = keyedSections[value] {
            currentSection = section
            parentList.insert(currentSection, after: self)
        }
    }

    func readSections() throws {
        try self.readCases()
        if cases.isEmpty {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ elements found.", comment: ""))
        }
        // Read KEYBs
        var keyBs: [ElementKEYB] = []
        while let keyB = parentList.pop("KEYB") as? ElementKEYB {
            // Allow one KEYB to be used for multiple CASEs
            let vals = (keyB.metaValue ?? keyB.displayLabel).components(separatedBy: ",")
            for value in vals {
                let key = cases.first(where: { $0.value.displayValue == value })?.key
                // A value of "*" that doesn't match a CASE will be a wildcard, used when the existing data doesn't match any cases
                guard key != nil || value == "*" else {
                    throw TemplateError.invalidStructure(keyB, NSLocalizedString("No corresponding ‘CASE’ element.", comment: ""))
                }
                guard keyedSections[key] == nil else {
                    throw TemplateError.invalidStructure(keyB, NSLocalizedString("Duplicate value.", comment: ""))
                }
                keyedSections[key] = keyB
            }
            keyB.parentList = parentList
            keyB.subElements = try parentList.subList(for: keyB)
            keyBs.append(keyB)
        }
        for (value, caseEl) in cases where keyedSections[value] == nil {
            throw TemplateError.invalidStructure(caseEl, NSLocalizedString("No corresponding ‘KEYB’ element.", comment: ""))
        }
        // Configure the KEYBs only after all of them are detached from the parent list
        for keyB in keyBs {
            try keyB.subElements.configure()
        }
    }

    override func configure(view: NSView) {
        var frame = view.frame
        frame.size.width = width-1
        frame.size.height = 24
        let keySelect = NSPopUpButton(frame: frame)
        keySelect.target = self
        keySelect.action = #selector(keyChanged(_:))
        keySelect.bind(.content, to: self, withKeyPath: "caseList")
        keySelect.bind(.selectedObject, to: self, withKeyPath: "value", options: [.valueTransformer: self])
        view.addSubview(keySelect)
    }

    @IBAction func keyChanged(_ sender: NSPopUpButton) {
        guard sender.indexOfSelectedItem < cases.keys.endIndex else {
            return
        }
        let oldSection = self.setCase(cases.keys[sender.indexOfSelectedItem])
        if oldSection != currentSection {
            if let oldSection {
                // Check if the section sizes match and attempt to copy the data
                let oldData = oldSection.subElements.getResourceData()
                let newData = currentSection.subElements.getResourceData()
                if oldData.count == newData.count {
                    try? currentSection.readData(from: BinaryDataReader(oldData))
                }
            }
            // Reload the view - note the outline item isn't necessarily self
            let outline = parentList.controller.dataList!
            let item = outline.item(atRow: outline.row(for: sender))
            outline.reloadItem(item, reloadChildren: true)
            outline.expandItem(item, expandChildren: true)
        }
        parentList.controller.itemValueUpdated(sender)
    }

    @discardableResult func setCase(_ value: AnyHashable) -> ElementKEYB? {
        let newSection = keyedSections[value] ?? keyedSections[nil]
        if newSection == currentSection {
            return currentSection
        }
        let oldSection = currentSection
        if let oldSection {
            self.parentList.remove(oldSection)
        }
        currentSection = newSection
        if let newSection {
            self.parentList.insert(newSection, after: self)
        }
        return oldSection
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return cases[value as! AnyHashable] ?? value
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return (value as! ElementCASE).value
    }

    // MARK: -

    var subElementCount: Int {
        currentSection?.subElementCount ?? 0
    }

    func subElement(at index: Int) -> BaseElement {
        return currentSection.subElement(at: index)
    }
}
