import Cocoa

class MenuItemTableRowView : NSTableRowView {
	
	enum RowStyle {
		case titleCell
		case firstItemCell
		case lastItemCell
		case middleCell // most cells
		case onlyCell
	}
	
	var rowStyle = RowStyle.middleCell
	
	override func draw(_ dirtyRect: NSRect) {
		var box = bounds.insetBy(dx: 2, dy: 0)
		
		NSColor.black.setStroke()
		
		switch rowStyle {
			
		case .titleCell:
			if !isSelected {
				NSColor.darkGray.setFill()
			} else {
				NSColor.selectedMenuItemColor.setFill()
			}
			NSBezierPath.fill(box)
		case .lastItemCell:
			box.origin.y -= 10 + 1 // 1 extra for shadow.
			box.size.height += 10
			let shadowBox = box.offsetBy(dx: 1, dy: 1)
			NSColor.black.setFill()
			NSBezierPath.fill(shadowBox)
			if !isSelected {
				NSColor.white.setFill()
			} else {
				NSColor.selectedMenuItemColor.setFill()
			}
			NSBezierPath.fill(box)
			NSBezierPath.stroke(box)
		case .firstItemCell:
			box.size.height += 20
			let shadowBox = box.offsetBy(dx: 1, dy: 1)
			NSColor.black.setFill()
			NSBezierPath.fill(shadowBox)
			if !isSelected {
				NSColor.white.setFill()
			} else {
				NSColor.selectedMenuItemColor.setFill()
			}
			NSBezierPath.fill(box)
			NSBezierPath.stroke(box)
		case .middleCell:
			box.origin.y -= 10
			box.size.height += 20
			let shadowBox = box.offsetBy(dx: 1, dy: 1)
			NSColor.black.setFill()
			NSBezierPath.fill(shadowBox)
			if !isSelected {
				NSColor.white.setFill()
			} else {
				NSColor.selectedMenuItemColor.setFill()
			}
			NSBezierPath.fill(box)
			NSBezierPath.stroke(box)
		case .onlyCell:
			let shadowBox = box.offsetBy(dx: 1, dy: 1)
			NSColor.black.setFill()
			NSBezierPath.fill(shadowBox)
			if !isSelected {
				NSColor.white.setFill()
			} else {
				NSColor.selectedMenuItemColor.setFill()
			}
			NSBezierPath.fill(box)
			NSBezierPath.stroke(box)
		}
	}
	
}
