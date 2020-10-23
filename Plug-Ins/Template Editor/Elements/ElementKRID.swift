import Cocoa

class ElementKRID: KeyElement, GroupElement {
    private var caseEl: ElementCASE!
    
    override func configure() throws {
        self.rowHeight = 18
        try self.readCases()
        // Get the current resource id
        caseEl = self.caseMap[String(self.parentList.controller.resource.id)]
        guard caseEl != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘KEYB’ for this resource id.", comment: ""))
        }
        self.currentSection = self.keyedSections[caseEl]
        self.parentList.insert(self.currentSection)
    }
    
    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = "\(self.displayLabel): \(caseEl.displayLabel)"
    }
}
