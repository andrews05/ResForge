import Cocoa
import RKSupport

class ElementCASE: Element, GroupElement {
    var displayValue: String = ""
    @objc var value: AnyHashable!
    
    required init(type: String, label: String, tooltip: String? = nil) {
        super.init(type: type, label: label, tooltip: tooltip)
    }
    
    init(value: AnyHashable, displayValue: String) {
        super.init(type: "CASE", label: displayValue, tooltip: "")
        self.displayValue = displayValue
        self.value = value
    }
    
    // For key elements, the case's description is used in the popup menu
    override var description: String {
        self.displayLabel
    }
    
//    override func configure() throws {
//        throw TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a supported element.", comment: ""))
//    }
    
    // Soft fail unsupported cases
    func configureGroup(view: NSTableCellView) {
        let error = TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a supported element.", comment: ""))
        view.textField?.stringValue = error.errorDescription!
    }
    
    func configure(for element: Element) throws {
        displayValue = String(label.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).last!)
        if let formatter = element.formatter {
            var errorString: NSString? = nil
            var ioValue: AnyObject?
            formatter.getObjectValue(&ioValue, for: displayValue, errorDescription: &errorString)
            if let errorString = errorString {
                throw TemplateError.invalidStructure(self, errorString as String)
            }
            value = ioValue as? AnyHashable
        } else {
            value = displayValue
        }
    }
}
