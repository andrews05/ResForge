import Cocoa
import RKSupport

class ElementCASE: Element {
    let title: String
    let value: String
    var objectValue: AnyObject!
    
    // Cases will show as "title = value" in the options list to allow searching by title
    // Text field will display as "value = title" for consistency when there's no matching case
    var optionLabel: String {
        "\(title) = \(value)"
    }
    override var displayLabel: String {
        "\(value) = \(title)"
    }
    
    // For key elements, the case's description is displayed in the popup menu
    override var description: String {
        title
    }
 
    required init(type: String, label: String, tooltip: String? = nil) {
        // The case value is the part of the label to the right of the "=" character if it exists, else the label itself
        let split = label.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        title = String(split.first!)
        value = String(split.last!)
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = false
    }
    
    override func configure() throws {
        throw TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a supported element.", comment: ""))
    }
    
    func configure(for element: Element) throws {
        if let formatter = element.formatter {
            var errorString: NSString? = nil
            formatter.getObjectValue(&objectValue, for: value, errorDescription: &errorString)
            if let errorString = errorString {
                throw TemplateError.invalidStructure(self, errorString as String)
            }
        } else {
            objectValue = value as AnyObject
        }
    }
}
