import Cocoa


/// The "document area" of our scroll view, in which we show the DITL items.
public class DITLDocumentView : NSView {
    public override var isFlipped: Bool {
        get {
            return true
        }
        set(newValue) {
            
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let fillColor = NSColor.white
        let strokeColor = NSColor.systemGray
        fillColor.setFill()
        strokeColor.setStroke()
        NSBezierPath.fill(self.bounds)
        NSBezierPath.stroke(self.bounds)
    }
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        var didChange = false
        for itemView in subviews {
            if let itemView = itemView as? DITLItemView,
               itemView.selected {
                if !didChange {
                    NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: self)
                }
                itemView.selected = false
                itemView.needsDisplay = true
                didChange = true
            }
        }
        if didChange {
            NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: self)
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

extension DITLDocumentView {
    
    /// Notification sent whenever a ``DITLItemView`` inside this view is clicked and it is about to cause a change in selected items.
    /// Also sent when this view itself is clicked and all items are about to be deselected.
    static let selectionWillChangeNotification = Notification.Name("DITLItemViewSelectionWillChangeNotification")
    
    /// Notification sent whenever a ``DITLItemView`` inside this view is clicked and it causes a change in selected items.
    /// Also sent when this view itself is clicked and all items are deselected.
    static let selectionDidChangeNotification = Notification.Name("DITLItemViewSelectionDidChangeNotification")
    
    /// Notification sent whenever a ``DITLItemView`` inside this view is resized or moved.
    static let itemFrameDidChangeNotification = Notification.Name("DITLItemViewFrameDidChangeNotification")
    
    /// Notification sent whenever a ``DITLItemView`` inside this view is double clicked.
    static let itemDoubleClickedNotification = Notification.Name("DITLItemDoubleClickedNotification")
    
    /// Notification userInfo key under which the clicked view for
    /// ``itemDoubleClickedNotification`` is stored.
    static let doubleClickedItemView = "DITLItemDoubleClickedItem"
}
