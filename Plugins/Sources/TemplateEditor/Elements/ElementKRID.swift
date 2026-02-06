import AppKit

class ElementKRID: KeyElement, GroupElement {
    override func configure() throws {
        rowHeight = 16
        // Read CASEs
        try self.readCases()
        let caseEl = cases[parentList.controller.resource.id]
        // Read KEYBs
        while let keyB = parentList.pop("KEYB") as? ElementKEYB {
            keyB.subElements = try parentList.subList(for: keyB)
            let vals = keyB.label.components(separatedBy: ",")
            if vals.contains(caseEl?.displayValue ?? "*") {
                currentSection = keyB
            }
        }
        guard currentSection != nil else {
            if let caseEl {
                throw TemplateError.invalidStructure(caseEl, NSLocalizedString("No corresponding ‘KEYB’ element.", comment: ""))
            }
            parentList.remove(self)
            return
        }
        currentSection.parentList = parentList
        parentList.insert(currentSection)
        try currentSection.subElements.configure()
        displayLabel += ": \(caseEl?.displayLabel ?? "Other")"
    }

    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = displayLabel
    }

    override var formatter: Formatter {
        self.sharedFormatter("INT16") { IntFormatter<Int16>() }
    }
}
