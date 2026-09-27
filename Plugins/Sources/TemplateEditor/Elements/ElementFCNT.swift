import AppKit

class ElementFCNT: BaseElement, GroupElement, CounterElement {
    var count = 0
    private var groupLabel = ""

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        groupLabel = displayLabel
        // The count must be at the start of either the label or the meta value
        if let remainder = self.readCount(from: groupLabel) {
            groupLabel = remainder.trimmingCharacters(in: .whitespaces)
        } else if let metaValue {
            _ = self.readCount(from: metaValue)
        }
        // Hide if no remaining label
        visible = !groupLabel.isEmpty
    }

    func readCount(from string: String) -> Substring? {
        let scanner = Scanner(string: string)
        scanner.charactersToBeSkipped = nil
        // Hex value denoted by leading '$' or '0x'
        let value = if scanner.scanString("$") != nil || string.starts(with: "0x") {
            scanner.scanInt32(representation: .hexadecimal)
        } else {
            scanner.scanInt32()
        }
        if let value, value > 0 {
            count = Int(value)
            // Return the rest of the string
            return string[scanner.currentIndex...]
        }
        return nil
    }

    override func configure() throws {
        guard count > 0 else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Could not determine list count from label.", comment: ""))
        }
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
