import Cocoa

class ElementFCNT: Element, GroupElement, CounterElement {
    var count: Int
    private let groupLabel: String
    
    required init(type: String, label: String, tooltip: String? = nil) {
        // Read count from label - hex value denoted by leading '$'
        let scanner = Scanner(string: label)
        if label.first == "$" {
            scanner.scanLocation = 1
            var value: UInt32 = 0
            scanner.scanHexInt32(&value)
            count = Int(value)
        } else {
            var value: Int32 = 0
            scanner.scanInt32(&value)
            count = Int(abs(value))
        }
        // Remove count from label
        groupLabel = label.dropFirst(scanner.scanLocation).trimmingCharacters(in: .whitespaces)
        super.init(type: type, label: label, tooltip: tooltip)
        // Hide if no remaining label
        self.visible = !groupLabel.isEmpty
    }
    
    override func configure() throws {
        self.rowHeight = 18
        guard let lstc = self.parentList.next(ofType: "LSTC") as? ElementLSTB else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Following ‘LSTC’ element not found.", comment: ""))
        }
        lstc.counter = self
        lstc.visible = false
        lstc.fixedCount = true
    }
    
    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = "\(self.groupLabel) = \(self.count)"
    }
}
