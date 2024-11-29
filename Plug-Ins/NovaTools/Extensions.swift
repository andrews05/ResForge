import AppKit

extension AffineTransform {
    /// Applies the affine transform to the specified rectangle.
    func transform(_ rect: NSRect) -> NSRect {
        NSRect(origin: transform(rect.origin), size: transform(rect.size))
    }
}

extension NSPoint {
    // NSPoint only directly conforms to Hashable since macOS 15
    struct Hash: Hashable {
        let x: Double
        let y: Double
    }
    var hashable: Hash { .init(x: x, y: y) }

    /// Returns the nearest point to this one that lies within the given rectangle.
    func constrained(within rect: NSRect) -> Self {
        Self(x: min(max(x, rect.minX), rect.maxX), y: min(max(y, rect.minY), rect.maxY))
    }
}

extension NSRect {
    /// The center point of the specified rectangle.
    var center: NSPoint {
        get { .init(x: midX, y: midY) }
        set {
            origin.x = newValue.x - width / 2
            origin.y = newValue.y - height / 2
        }
    }
}

extension NSView {
    /// Scrolls the view’s closest ancestor NSClipView object so a point in the view lies at the center of clip view's bounds rectangle.
    func centerScroll(_ point: NSPoint) {
        if let viewRect = enclosingScrollView?.contentView.frame {
            self.scroll(NSPoint(x: point.x - viewRect.midX, y: point.y - viewRect.midY))
        }
    }
}
