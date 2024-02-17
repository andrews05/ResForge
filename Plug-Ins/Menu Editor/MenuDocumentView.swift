import Cocoa


/// The "document area" of our scroll view, in which we show the Menu items.
public class MenuDocumentView : NSView {
    public override var isFlipped: Bool {
        get {
            return true
        }
        set(newValue) {
            
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let fillColor = NSColor.white
        let strokeColor = NSColor.black
        fillColor.setFill()
        strokeColor.setStroke()
		var box = self.bounds
		var shadowBox = box.offsetBy(dx: 1, dy: 1)
		shadowBox.origin.y += 2
		shadowBox.size.height -= 2
		shadowBox.origin.x += 2
		shadowBox.size.width -= 2
		box.size.width -= 1;
		box.size.height -= 1;
        NSBezierPath.fill(box)
        NSBezierPath.stroke(box)
    }
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        var didChange = false
        for itemView in subviews {
            if let itemView = itemView as? MenuItemView,
               itemView.selected {
                if !didChange {
                    NotificationCenter.default.post(name: MenuDocumentView.selectionWillChangeNotification, object: self)
                }
                itemView.selected = false
                itemView.needsDisplay = true
                didChange = true
            }
        }
        if didChange {
            NotificationCenter.default.post(name: MenuDocumentView.selectionDidChangeNotification, object: self)
        }
    }
    
    public override var canBecomeKeyView: Bool {
        return true
    }
    
    public override var acceptsFirstResponder: Bool {
        return true
    }
    
    public override func resignFirstResponder() -> Bool {
        return true
    }
}

extension MenuDocumentView {
    
    /// Notification sent whenever a ``MenuItemView`` inside this view is clicked and it is about to cause a change in selected items.
    /// Also sent when this view itself is clicked and all items are about to be deselected.
    static let selectionWillChangeNotification = Notification.Name("MenuItemViewSelectionWillChangeNotification")
    
    /// Notification sent whenever a ``MenuItemView`` inside this view is clicked and it causes a change in selected items.
    /// Also sent when this view itself is clicked and all items are deselected.
    static let selectionDidChangeNotification = Notification.Name("MenuItemViewSelectionDidChangeNotification")
    
    /// Notification sent whenever a ``MenuItemView`` inside this view is resized or moved.
    static let itemFrameDidChangeNotification = Notification.Name("MenuItemViewFrameDidChangeNotification")
    
    /// Notification sent whenever a ``MenuItemView`` inside this view is double clicked.
    static let itemDoubleClickedNotification = Notification.Name("MenuItemDoubleClickedNotification")
    
    /// Notification userInfo key under which the clicked view for
    /// ``itemDoubleClickedNotification`` is stored.
    static let doubleClickedItemView = "MenuItemDoubleClickedItem"
}
