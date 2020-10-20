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
        let index = label.index(label.startIndex, offsetBy: scanner.scanLocation)
        groupLabel = label.suffix(from: index).trimmingCharacters(in: .whitespaces)
        super.init(type: type, label: label, tooltip: tooltip)
        self.rowHeight = 17
        // Hide if no remaining label
        self.visible = groupLabel.count > 0
    }
    
    override func configure() throws {
        guard let lstc = self.parentList.next(ofType: "LSTC") as? ElementLSTB else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Following ‘LSTC’ element not found.", comment: ""))
        }
        lstc.counter = self
    }
    
    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = "\(self.groupLabel) = \(self.count)"
    }
}
