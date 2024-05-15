import AppKit

class MenuItemTableRowView : NSTableRowView {
    
    enum RowStyle {
        case titleCell
        case firstItemCell
        case lastItemCell
        case middleCell // most cells
        case onlyCell
    }
    
    enum ContentStyle {
        case normal
        case separator
        case submenu // Like normal, but with an arrow on the right.
    }
    
    var rowStyle = RowStyle.middleCell {
        didSet {
            self.needsDisplay = true
        }
    }
    var contentStyle = ContentStyle.normal {
        didSet {
            self.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        var box = bounds.insetBy(dx: 2, dy: 0)
        
        NSColor.textColor.setStroke()
        
        switch rowStyle {
            
        case .titleCell:
            box.origin.x += 16 // keep these two lines in sync with XIB "Mark" and "Shortcut" column widths.
            box.size.width -= 16 + 25;
            if !isSelected {
                NSColor.textColor.setFill()
            } else {
                NSColor.selectedMenuItemColor.setFill()
            }
            NSBezierPath.fill(box)
        case .lastItemCell:
            box.origin.y -= 10 + 1 // 1 extra for shadow.
            box.size.height += 10
            var shadowBox = box.offsetBy(dx: 2, dy: 1)
            shadowBox.size.width -= 1
            NSColor.textColor.setFill()
            NSBezierPath.fill(shadowBox)
            if !isSelected {
                NSColor.textBackgroundColor.setFill()
            } else {
                NSColor.selectedMenuItemColor.setFill()
            }
            NSBezierPath.fill(box)
            NSBezierPath.stroke(box.insetBy(dx: 0.5, dy: 0.5))
        case .firstItemCell:
            box.size.height += 20
            let shadowBox = box.offsetBy(dx: 1, dy: 2)
            NSColor.textColor.setFill()
            NSBezierPath.fill(shadowBox)
            if !isSelected {
                NSColor.textBackgroundColor.setFill()
            } else {
                NSColor.selectedMenuItemColor.setFill()
            }
            NSBezierPath.fill(box)
            NSBezierPath.stroke(box.insetBy(dx: 0.5, dy: 0.5))
        case .middleCell:
            box.origin.y -= 10
            box.size.height += 20
            let shadowBox = box.offsetBy(dx: 1, dy: 1)
            NSColor.textColor.setFill()
            NSBezierPath.fill(shadowBox)
            if !isSelected {
                NSColor.textBackgroundColor.setFill()
            } else {
                NSColor.selectedMenuItemColor.setFill()
            }
            NSBezierPath.fill(box)
            NSBezierPath.stroke(box.insetBy(dx: 0.5, dy: 0.5))
        case .onlyCell:
            box.size.height -= 1
            var shadowBox = box.offsetBy(dx: 1, dy: 1)
            shadowBox.origin.x += 1
            shadowBox.size.width -= 1
            shadowBox.origin.y += 1
            shadowBox.size.height -= 1
            NSColor.textColor.setFill()
            NSBezierPath.fill(shadowBox)
            if !isSelected {
                NSColor.textBackgroundColor.setFill()
            } else {
                NSColor.selectedMenuItemColor.setFill()
            }
            NSBezierPath.fill(box)
            NSBezierPath.stroke(box.insetBy(dx: 0.5, dy: 0.5))
        }
        
        if contentStyle == .separator {
            let contentBox = bounds.insetBy(dx: 2, dy: 0)
            NSColor.lightGray.setStroke()
            NSBezierPath.strokeLine(from: NSPoint(x: contentBox.minX + 1, y: trunc(contentBox.midY) + 0.5), to: NSPoint(x: contentBox.maxX - 1, y: trunc(contentBox.midY) + 0.5))
        } else if contentStyle == .submenu {
            var contentBox = bounds.insetBy(dx: 3, dy: 3)
            contentBox.size.width = contentBox.size.height / 2.0
            contentBox.origin.x = bounds.maxX - 6 - contentBox.size.width
            let triangle = NSBezierPath()
            triangle.move(to: contentBox.origin)
            triangle.line(to: NSPoint(x: contentBox.origin.x, y: contentBox.maxY))
            triangle.line(to: NSPoint(x: contentBox.maxX, y: contentBox.midY))
            triangle.line(to: contentBox.origin)
            NSColor.textColor.setFill()
            triangle.fill()
        }
    }
    
}
