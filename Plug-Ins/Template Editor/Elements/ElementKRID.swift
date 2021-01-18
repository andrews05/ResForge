import Cocoa

class ElementKRID: KeyElement, GroupElement {
    private var caseEl: ElementCASE!
    
    override func configure() throws {
        self.rowHeight = 18
        // Get the current resource id
        let rID = String(self.parentList.controller.resource.id)
        // Read CASEs
        while let el = self.parentList.pop("CASE") as? ElementCASE {
            try el.configure(for: self)
            if el.displayValue == rID {
                caseEl = el
            }
        }
        guard caseEl != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ for this resource id.", comment: ""))
        }
        // Read KEYBs
        while let keyB = self.parentList.pop("KEYB") as? ElementKEYB {
            keyB.subElements = try parentList.subList(for: keyB)
            let vals = keyB.label.components(separatedBy: ",")
            if vals.contains(rID) {
                try keyB.subElements.configure()
                self.currentSection = keyB
            }
        }
        guard self.currentSection != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘KEYB’ for this resource id.", comment: ""))
        }
        self.parentList.insert(self.currentSection)
    }
    
    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = "\(self.displayLabel): \(caseEl.displayLabel)"
    }
}
