import Cocoa

class ElementKRID: KeyElement, GroupElement {
    override func configure() throws {
        self.rowHeight = 18
        // Read CASEs
        try self.readCases()
        guard let caseEl = caseMap[parentList.controller.resource.id] else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ for this resource id.", comment: ""))
        }
        // Read KEYBs
        while let keyB = self.parentList.pop("KEYB") as? ElementKEYB {
            keyB.subElements = try parentList.subList(for: keyB)
            let vals = keyB.label.components(separatedBy: ",")
            if vals.contains(caseEl.displayValue) {
                self.currentSection = keyB
            }
        }
        guard self.currentSection != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘KEYB’ for this resource id.", comment: ""))
        }
        self.currentSection.parentList = self.parentList
        self.parentList.insert(self.currentSection)
        try self.currentSection.subElements.configure()
        self.displayLabel += ": \(caseEl.displayLabel)"
    }
    
    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = self.displayLabel
    }
    
    override var formatter: Formatter {
        self.sharedFormatter("INT16") { IntFormatter<Int16>() }
    }
}
