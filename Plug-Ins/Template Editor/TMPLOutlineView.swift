import Cocoa

// Table views don't support tabbing between rows so we need to handle the key view loop manually
class TMPLOutlineView: NSOutlineView {
    @objc func selectPreviousKeyView(_ sender: Any) {
        var view = self.window!.firstResponder as! NSView
        if view.previousValidKeyView != nil && view.previousValidKeyView != self {
            self.window?.selectPreviousKeyView(view)
            return
        }
        let row = self.row(for: view)
        var i = row-1
        // Loop through all rows. Break if we come back to where we started without having found anything.
        while i != row {
            if i == -1 {
                continue
            }
            if i == -2 {
                i = self.numberOfRows
                continue
            }
            // Going backward we need to look at the column view and see if it's valid
            view = self.view(atColumn: 1, row: i, makeIfNecessary: true)!
            if !view.canBecomeKeyView {
                view = view.subviews.last!
            }
            if !view.canBecomeKeyView {
                view = self.view(atColumn: 0, row: i, makeIfNecessary: true)!
            }
            if view.canBecomeKeyView {
                self.window?.makeFirstResponder(view)
                view.scrollToVisible(view.superview!.bounds)
                return
            }
            i -= 1
        }
    }
    
    @objc func selectNextKeyView(_ sender: Any) {
        var view: NSView! = self.window?.firstResponder as? NSView
        if view.nextValidKeyView != nil {
            self.window?.selectNextKeyView(view)
            return
        }
        let row = self.row(for: view)
        var i = row+1
        while i != row {
            if i == -1 {
                continue
            }
            if i == self.numberOfRows {
                i = -2
                continue
            }
            // Going forward we can ask the row for its nextValidKeyView
            view = self.rowView(atRow: i, makeIfNecessary: true)?.nextValidKeyView
            if view != nil {
                self.window?.makeFirstResponder(view)
                view.scrollToVisible(view.superview!.bounds)
                return
            }
            i += 1
        }
    }
    
    // Don't draw the disclosure triangles
    override func frameOfOutlineCell(atRow row: Int) -> NSRect {
        return NSZeroRect
    }
    
    // Manually manage indentation for list headers
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        var superFrame = super.frameOfCell(atColumn: column, row: row)
        if column == 0 && self.item(atRow: row) is ElementLSTB {
            let indent = self.level(forRow: row) * 16
            superFrame.origin.x += CGFloat(indent)
            superFrame.size.width -= CGFloat(indent)
        }
        return superFrame
    }
}
