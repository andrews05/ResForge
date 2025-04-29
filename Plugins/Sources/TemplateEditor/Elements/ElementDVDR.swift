import AppKit

class ElementDVDR: BaseElement, GroupElement {
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        if label.isEmpty {
            rowHeight = 1
        } else {
            rowHeight = Double(label.components(separatedBy: "\n").count * 15) + 1
        }
    }

    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = label
    }
}
