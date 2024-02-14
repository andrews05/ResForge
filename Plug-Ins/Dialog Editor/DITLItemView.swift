import Cocoa
import RFSupport

/// View that shows a simple preview for a System 7 DITL item:
/// This view must be an immediate subview of a ``DITLDocumentView``.
class DITLItemView : NSView {
	/// The text to display on the item (button title or text view text:
	var title: String
	/// Other info from the DITL resource about this item:
	var type: DITLItem.DITLItemType {
		didSet {
			reloadImage()
		}
	}
	/// Is this object selected for editing/moving/resizing?
	var selected = false
	/// Resource referenced by this item (e.g. ICON ID for an icon item PICT for picture, CNTL for control etc.)
	var resourceID = 0 {
		didSet {
			reloadImage()
		}
	}
		
	/// Is this item clickable?
	var enabled: Bool
	private var image: NSImage?
	/// Object that lets us look up icons and images.
	private let manager: RFEditorManager
	
	static let rightEdgeIndices = [0, 1, 2]
	static let leftEdgeIndices = [4, 5, 6]
	static let bottomEdgeIndices = [0, 6, 7]
	static let topEdgeIndices = [2, 3, 4]
	
	init(frame frameRect: NSRect, title: String, type: DITLItem.DITLItemType, enabled: Bool, resourceID: Int, manager: RFEditorManager) {
		self.title = title
		self.type = type
		self.enabled = enabled
		self.resourceID = resourceID
		self.manager = manager
		super.init(frame: frameRect)
		
		if #available(macOS 14, *) { // If built w. macOS 14+ SDK, this defaults to false.
			clipsToBounds = true
		}
		reloadImage()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	/// Load the picture or icon associated with this dialog:
	private func reloadImage() {
		var resource: Resource?
		switch type {
		case .picture:
			resource = manager.findResource(type: ResourceType("PICT"), id: resourceID, currentDocumentOnly: true)
		case .icon:
			resource = manager.findResource(type: ResourceType("cicn"), id: resourceID, currentDocumentOnly: true)
			if resource == nil {
				resource = manager.findResource(type: ResourceType("ICON"), id: resourceID, currentDocumentOnly: true)
			}
		default:
			resource = nil
		}
		if let resource = resource {
			resource.preview { img in
				self.image = img
				self.needsDisplay = true
			}
		} else {
			self.image = nil
			self.needsDisplay = true
		}
	}

	/// Resize the view in response to a click on one of the 8 "handles":
	private func trackKnob(_ index: Int, for startEvent: NSEvent) {
		var lastPos = superview!.convert(startEvent.locationInWindow, from: nil)
		var keepTracking = true
		var didChange = false
		while keepTracking {
			let currEvent = NSApplication.shared.nextEvent(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp], until: Date.distantFuture, inMode: .eventTracking, dequeue: true)
			if let currEvent = currEvent {
				switch currEvent.type {
				case .leftMouseDown, .leftMouseUp:
					keepTracking = false
				case .leftMouseDragged:
					let currPos = superview!.convert(currEvent.locationInWindow, from: nil)
					let distance = NSSize(width: currPos.x - lastPos.x, height: currPos.y - lastPos.y)
					var box = frame
					if DITLItemView.rightEdgeIndices.contains(index) {
						box.size.width += distance.width
					} else if DITLItemView.leftEdgeIndices.contains(index) {
						box.size.width -= distance.width
						box.origin.x += distance.width
					}
					if DITLItemView.bottomEdgeIndices.contains(index) {
						box.size.height += distance.height
					} else if DITLItemView.topEdgeIndices.contains(index) {
						box.size.height -= distance.height
						box.origin.y += distance.height
					}
					if !didChange {
						self.undoManager?.beginUndoGrouping()
						self.undoManager?.setActionName(NSLocalizedString("Resize Item", comment: ""))
						didChange = true
					}
					let oldFrame = frame
					self.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoMove(oldFrame: oldFrame) })
					frame = box
					lastPos = currPos
				default:
					keepTracking = false
				}
			}
		}
		if didChange {
			self.undoManager?.endUndoGrouping()
			NotificationCenter.default.post(name: DITLDocumentView.itemFrameDidChangeNotification, object: superview)
		}
	}
	
	private func undoRedoMove(oldFrame: NSRect) {
		let newFrame = frame
		frame = oldFrame
		self.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoMove(oldFrame: newFrame) })
	}
	
	/// Move the view and any other selected views around in response to the user dragging it.
	private func trackDrag(for startEvent: NSEvent) {
		var lastPos = superview!.convert(startEvent.locationInWindow, from: nil)
		var keepTracking = true
		var didChange = false
		while keepTracking {
			let currEvent = NSApplication.shared.nextEvent(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp], until: Date.distantFuture, inMode: .eventTracking, dequeue: true)
			if let currEvent = currEvent {
				switch currEvent.type {
				case .leftMouseDown, .leftMouseUp:
					keepTracking = false
				case .leftMouseDragged:
					let currPos = superview!.convert(currEvent.locationInWindow, from: nil)
					let distance = NSSize(width: currPos.x - lastPos.x, height: currPos.y - lastPos.y)
					for itemView in superview?.subviews ?? [] {
						if let itemView = itemView as? DITLItemView,
						   itemView.selected {
							if !didChange {
								self.undoManager?.beginUndoGrouping()
								self.undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
								didChange = true
							}
							let oldFrame = frame
							self.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoMove(oldFrame: oldFrame) })
							let box = itemView.frame.offsetBy(dx: distance.width, dy: distance.height)
							itemView.frame = box
						}
					}
					lastPos = currPos
				default:
					keepTracking = false
				}
			}
		}
		if didChange {
			self.undoManager?.endUndoGrouping()
			NotificationCenter.default.post(name: DITLDocumentView.itemFrameDidChangeNotification, object: superview)
		}
	}
	
	override func mouseDown(with event: NSEvent) {
		needsDisplay = true
		if event.modifierFlags.contains(.shift) { // Multi-selection.
			NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: superview)
			selected = !selected
			NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: superview)
		} else if selected { // Drag/resize of selected items.
			var knobIndex = 0
			let pos = convert(event.locationInWindow, from: nil)
			for knob in calculateKnobRects() {
				if let knob = knob, knob.contains(pos) {
					trackKnob(knobIndex, for: event)
					return
				}
				knobIndex += 1
			}
			if (event.clickCount % 2) == 0 {
				NotificationCenter.default.post(name: DITLDocumentView.itemDoubleClickedNotification, object: superview, userInfo: [DITLDocumentView.doubleClickedItemView: self])
			} else {
				trackDrag(for: event)
			}
		} else { // Select and possibly drag around an unselected item:
			NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: superview)
			selected = true
			for itemView in superview?.subviews ?? [] {
				if let itemView = itemView as? DITLItemView,
				   itemView.selected, itemView != self {
					itemView.selected = false
					itemView.needsDisplay = true
				}
			}
			NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: superview)
			if (event.clickCount % 2) == 0 {
				NotificationCenter.default.post(name: DITLDocumentView.itemDoubleClickedNotification, object: superview, userInfo: [DITLDocumentView.doubleClickedItemView: self])
			} else {
				trackDrag(for: event)
			}
		}
	}
	
	override func draw(_ dirtyRect: NSRect) {
		switch type {
		case .userItem:
			let fillColor = (NSColor.systemBlue.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray).withAlphaComponent(0.7)
			let strokeColor = NSColor.systemBlue.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemBlue, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .button:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			let lozenge = NSBezierPath(roundedRect: self.bounds, xRadius: 8.0, yRadius: 8.0)
			lozenge.fill()
			lozenge.stroke()
			
			let ps = NSMutableParagraphStyle()
			ps.alignment = .center
			ps.lineBreakMode = .byTruncatingTail
			let attrs: [NSAttributedString.Key:Any] = [
				.foregroundColor: strokeColor, .paragraphStyle: ps,
				.font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0) ?? .systemFont(ofSize: 12)
			]
			let measuredSize = title.size(withAttributes: attrs)
			var textBox = self.bounds
			textBox.origin.y += (textBox.size.height - measuredSize.height) / 2.0
			textBox.size.height = measuredSize.height
			title.draw(in: textBox, withAttributes: attrs)
		case .checkBox:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			var box = self.bounds
			box.size.width = box.size.height
			box = box.insetBy(dx: 2, dy: 2)
			NSBezierPath.stroke(box)
			NSBezierPath.fill(box)
			
			title.draw(at: NSPoint(x: box.maxX + 4, y: 0), withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .radioButton:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			var box = self.bounds
			box.size.width = box.size.height
			box = box.insetBy(dx: 2, dy: 2)
			let lozenge = NSBezierPath(ovalIn: box)
			lozenge.fill()
			lozenge.stroke()
			
			title.draw(at: NSPoint(x: box.maxX + 4, y: 0), withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .control:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
		case .staticText:
			title.draw(in: self.bounds, withAttributes: [.foregroundColor: NSColor.black, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .editText:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(in: self.bounds, withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .icon:
			if let image = image {
				image.draw(in: self.bounds, from: .zero, operation: .sourceAtop, fraction: 1.0, respectFlipped: true, hints: nil)
			} else {
				NSColor.darkGray.setFill()
				NSBezierPath.fill(self.bounds)
			}
		case .picture:
			if let image = image {
				image.draw(in: self.bounds, from: .zero, operation: .sourceAtop, fraction: 1.0, respectFlipped: true, hints: nil)
			} else {
				NSColor.darkGray.setFill()
				NSBezierPath.fill(self.bounds)
			}
		case .helpItem:
			let fillColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
			let strokeColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
		default:
			let fillColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
			let strokeColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemRed, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		}
		
		// Draw selection outline and resize handles, if this view is selected.
		if selected {
			NSColor.controlAccentColor.set()
			NSBezierPath.stroke(self.bounds)
			for knob in calculateKnobRects() {
				if let knob = knob {
					NSBezierPath.fill(knob)
				}
			}
		}
	}
	
	/// Calculate the rects of all 8 resize knobs.
	/// - Returns: An array with an entry for each knob, starting at the lower right,
	/// 		  then continuing counter-clockwise. If this view's rectangle is too
	/// 		  small, some knobs are set to `nil`, to make as many fit as possible.
	func calculateKnobRects() -> [NSRect?] {
		var result = [NSRect?]()
		var knobSize = 8.0
		let box = self.bounds
		var middleKnobs = true
		var minimalKnobs = false
		if ((knobSize * 2.0) + 1) >= box.size.height || ((knobSize * 2.0) + 1) >= box.size.width {
			minimalKnobs = true
		} else if ((knobSize * 3.0) + 2) >= box.size.height || ((knobSize * 3.0) + 2) > box.size.width {
			middleKnobs = false
		} else if (knobSize + 1) > box.size.height || (knobSize + 1) > box.size.width {
			knobSize = min(box.size.height - 1, box.size.width - 1)
		}
		
		var tlBox = self.bounds
		tlBox.size.width = knobSize
		tlBox.size.height = knobSize
		tlBox.origin.x = box.maxX - tlBox.size.width
		tlBox.origin.y = box.maxY - tlBox.size.height
		result.append(tlBox)
		if !minimalKnobs {
			if middleKnobs {
				tlBox.origin.x = box.maxX - tlBox.size.width
				tlBox.origin.y = box.midY - (tlBox.size.height / 2)
				result.append(tlBox)
			} else {
				result.append(nil)
			}
			tlBox.origin.x = box.maxX - tlBox.size.width
			tlBox.origin.y = 0
			result.append(tlBox)
			if middleKnobs {
				tlBox.origin.x = box.midX - (tlBox.size.width / 2)
				tlBox.origin.y = 0
				result.append(tlBox)
			} else {
				result.append(nil)
			}
			tlBox.origin.x = 0
			tlBox.origin.y = 0
			result.append(tlBox)
			if middleKnobs {
				tlBox.origin.x = 0
				tlBox.origin.y = box.midY - (tlBox.size.height / 2)
				result.append(tlBox)
			} else {
				result.append(nil)
			}
			tlBox.origin.x = 0
			tlBox.origin.y = box.maxY - tlBox.size.height
			result.append(tlBox)
			if middleKnobs {
				tlBox.origin.x = box.midX - (tlBox.size.width / 2)
				tlBox.origin.y = box.maxY - tlBox.size.height
				result.append(tlBox)
			} else {
				result.append(nil)
			}
		} else {
			result.append(nil)
			result.append(nil)
			result.append(nil)
			result.append(nil)
			result.append(nil)
			result.append(nil)
			result.append(nil)
		}
		
		return result
	}
	
	/// It's usually more convenient when dealing with Quickdraw
	/// coordinates to make this view display flipped.
	public override var isFlipped: Bool {
		get {
			return true
		}
		set(newValue) {
			
		}
	}
}
