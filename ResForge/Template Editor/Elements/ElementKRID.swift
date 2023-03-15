import Cocoa

class ElementKRID: KeyElement, GroupElement {
    override func configure() throws {
        rowHeight = 16
        // Read CASEs
        try self.readCases()
        guard let caseEl = cases[parentList.controller.resource.id] else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ for this resource id.", comment: ""))
        }
        // Read KEYBs
        while let keyB = parentList.pop("KEYB") as? ElementKEYB {
            keyB.subElements = try parentList.subList(for: keyB)
            let vals = keyB.label.components(separatedBy: ",")
            if vals.contains(caseEl.displayValue) {
                currentSection = keyB
            }
        }
        guard currentSection != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘KEYB’ for this resource id.", comment: ""))
        }
        currentSection.parentList = parentList
        parentList.insert(currentSection)
        try currentSection.subElements.configure()
        displayLabel += ": \(caseEl.displayLabel)"
    }

    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = displayLabel
    }

    override var formatter: Formatter {
        self.sharedFormatter("INT16") { IntFormatter<Int16>() }
    }
}
