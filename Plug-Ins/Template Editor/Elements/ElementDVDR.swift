import Cocoa

class ElementDVDR: Element, GroupElement {
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        if label.isEmpty {
            self.rowHeight = 1
        } else {
            self.rowHeight = Double(label.components(separatedBy: "\n").count * 15) + 1
        }
    }
    
    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = self.label
    }
}
