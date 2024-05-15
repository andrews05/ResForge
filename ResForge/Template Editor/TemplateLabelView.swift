import Cocoa

/// Focusable label view for list headers, allows creating and deleting entries.
class TemplateLabelView: NSTableCellView {
    override var acceptsFirstResponder: Bool {
        return true
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

    @IBAction func createNewItem(_ sender: Any) {
        guard let dataList = self.superview?.superview as? NSOutlineView, let window = self.window else {
            return
        }
        let row = dataList.row(for: self)
        if let element = dataList.item(atRow: row) as? ElementLSTB, element.allowsCreateListEntry() {
            element.createListEntry()
            dataList.reloadData()
            let newHeader = dataList.view(atColumn: 0, row: row, makeIfNecessary: true)
            window.makeFirstResponder(newHeader)
            // Expand the item and scroll the new content into view
            dataList.expandItem(dataList.item(atRow: row), expandChildren: true)
            let lastChild = dataList.rowView(atRow: dataList.row(forItem: element), makeIfNecessary: true)
            lastChild?.scrollToVisible(lastChild!.bounds)
            newHeader?.scrollToVisible(newHeader!.superview!.bounds)
        }
    }

    @IBAction func delete(_ sender: Any) {
        guard let dataList = self.superview?.superview as? NSOutlineView, let window = self.window else {
            return
        }
        let row = dataList.row(for: self)
        if let element = dataList.item(atRow: row) as? ElementLSTB, element.allowsRemoveListEntry() {
            element.removeListEntry()
            dataList.reloadData()
            let newHeader = dataList.view(atColumn: 0, row: row, makeIfNecessary: true)
            window.makeFirstResponder(newHeader)
        }
    }
}
