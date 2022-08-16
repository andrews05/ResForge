import Cocoa

// Table views don't support tabbing between rows so we need to handle the key view loop manually
class TabbableOutlineView: NSOutlineView {
    @objc func selectPreviousKeyView(_ sender: Any) {
        let view = self.window!.firstResponder as! NSView
        if self.numberOfRows == 0 || (view.previousValidKeyView != nil && view.previousValidKeyView != self) {
            self.window?.selectPreviousKeyView(view)
            return
        }
        // Loop through all rows. Break if we come back to where we started without having found anything.
        var row = self.row(for: view) // -1 if not found
        if row == -1 {
            row = self.numberOfRows
        }
        var i = row-1
        while i != row {
            if i != -1, var view = self.view(atColumn: 1, row: i, makeIfNecessary: true) {
                if !view.canBecomeKeyView {
                    view = view.subviews.last { $0.canBecomeKeyView } ?? self.view(atColumn: 0, row: i, makeIfNecessary: true) ?? view
                }
                if view.canBecomeKeyView {
                    self.window?.makeFirstResponder(view)
                    view.scrollToVisible(view.superview!.bounds)
                    return
                }
            }
            i = i == -1 ? self.numberOfRows-1 : i-1
        }
    }
    
    @objc func selectNextKeyView(_ sender: Any) {
        let view = self.window!.firstResponder as! NSView
        if self.numberOfRows == 0 || view.nextValidKeyView != nil {
            self.window?.selectNextKeyView(view)
            return
        }
        var row = self.row(for: view)
        var i = row+1
        if row == -1 {
            row = self.numberOfRows
        }
        while i != row {
            if i != self.numberOfRows, var view = self.view(atColumn: 0, row: i, makeIfNecessary: true) {
                if !view.canBecomeKeyView, let cell = self.view(atColumn: 1, row: i, makeIfNecessary: true) {
                    view = cell.subviews.first { $0.canBecomeKeyView } ?? cell
                }
                if view.canBecomeKeyView {
                    self.window?.makeFirstResponder(view)
                    view.scrollToVisible(view.superview!.bounds)
                    return
                }
            }
            i = i == self.numberOfRows ? 0 : i+1
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
    
    // Add bottom padding
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(NSSize(width: newSize.width, height: newSize.height+5))
    }
}
