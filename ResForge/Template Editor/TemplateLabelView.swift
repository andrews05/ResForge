import AppKit
import RFSupport

public extension NSPasteboard.PasteboardType {
    static let RFTemplateListItem = Self("com.resforge.template-list-item")
}

/// Focusable label view for list headers, allows creating and deleting entries.
class TemplateLabelView: NSTableCellView {
    override var acceptsFirstResponder: Bool {
        return true
    }

    private var dataList: NSOutlineView? {
        superview?.superview as? NSOutlineView
    }

    override func mouseDown(with event: NSEvent) {
        self.window?.makeFirstResponder(self)
    }

    override var focusRingMaskBounds: NSRect {
        return self.textField!.frame
    }

    override func drawFocusRingMask() {
        self.focusRingMaskBounds.fill()
    }

    @IBAction func cut(_ sender: Any) {
        self.copy(sender)
        self.delete(sender)
    }

    @IBAction func copy(_ sender: Any) {
        guard let dataList else { return }
        let row = dataList.row(for: self)
        if let element = dataList.item(atRow: row) as? ElementLSTB {
            let writer = BinaryDataWriter()
            element.writeData(to: writer)
            NSPasteboard.general.declareTypes([.RFTemplateListItem], owner: nil)
            NSPasteboard.general.setData(writer.data, forType: .RFTemplateListItem)
        }
    }

    @IBAction func paste(_ sender: Any) {
        if let data = NSPasteboard.general.data(forType: .RFTemplateListItem) {
            self.createListItem(data)
        }
    }

    @IBAction func createNewItem(_ sender: Any) {
        self.createListItem()
    }

    private func createListItem(_ data: Data? = nil) {
        guard let dataList else { return }
        let row = dataList.row(for: self)
        if let element = dataList.item(atRow: row) as? ElementLSTB, element.createListEntry(data) {
            dataList.reloadData()
            let newHeader = dataList.view(atColumn: 0, row: row, makeIfNecessary: true)
            window?.makeFirstResponder(newHeader)
            // Expand the item and scroll the new content into view
            dataList.expandItem(dataList.item(atRow: row), expandChildren: true)
            let lastChild = dataList.rowView(atRow: dataList.row(forItem: element), makeIfNecessary: true)
            lastChild?.scrollToVisible(lastChild!.bounds)
            newHeader?.scrollToVisible(newHeader!.superview!.bounds)
        }
    }

    @IBAction func delete(_ sender: Any) {
        guard let dataList else { return }
        let row = dataList.row(for: self)
        if let element = dataList.item(atRow: row) as? ElementLSTB, element.removeListEntry() {
            dataList.reloadData()
            let newHeader = dataList.view(atColumn: 0, row: row, makeIfNecessary: true)
            window?.makeFirstResponder(newHeader)
        }
    }
}
