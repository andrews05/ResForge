import Cocoa

class ElementCASE: CaseableElement {
    let value: String
 
    required init(type: String, label: String, tooltip: String? = nil) {
        // The case value is the part of the label to the right of the "=" character if it exists, else the label itself
        self.value = String(label.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).last!)
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = false
    }
    
    override func configure() throws {
        throw TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a supported element.", comment: ""))
    }
}
