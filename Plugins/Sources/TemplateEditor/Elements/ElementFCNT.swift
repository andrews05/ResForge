import AppKit

class ElementFCNT: BaseElement, GroupElement, CounterElement {
    var count: Int
    private let groupLabel: String

    required init(type: String, label: String) {
        // Read count from label - hex value denoted by leading '$' or '0x'
        let scanner = Scanner(string: label)
        if scanner.scanString("$") != nil {
            let value = scanner.scanInt32(representation: .hexadecimal) ?? 0
            count = Int(value)
        } else if label.starts(with: "0x") {
            let value = scanner.scanInt32(representation: .hexadecimal) ?? 0
            count = Int(value)
        } else {
            let value = scanner.scanInt32() ?? 0
            count = Int(abs(value))
        }
        // Remove count from label
        groupLabel = label[scanner.currentIndex...].trimmingCharacters(in: .whitespaces)
        super.init(type: type, label: label)
        // Hide if no remaining label
        visible = !groupLabel.isEmpty
    }

    override func configure() throws {
        rowHeight = 16
        guard let lstc = parentList.next(ofType: "LSTC") as? ElementLSTB else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Following ‘LSTC’ element not found.", comment: ""))
        }
        lstc.counter = self
        lstc.visible = false
        lstc.fixedCount = true
    }

    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = "\(groupLabel) = \(count)"
    }
}
