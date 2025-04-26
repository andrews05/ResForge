import AppKit
import RFSupport

/// View that shows a simple preview for a System 7 DITL item:
/// This view must be an immediate subview of a ``DITLDocumentView``.
class DITLItemView: NSView {
    /// The text to display on the item (button title or text view text:
    var title: String
    /// Other info from the DITL resource about this item:
    var type: DITLItem.DITLItemType {
        didSet {
            self.reloadImage()
        }
    }
    /// Is this object selected for editing/moving/resizing?
    var selected = false
    /// Resource referenced by this item (e.g. ICON ID for an icon item PICT for picture, CNTL for control etc.)
    var resourceID = 0 {
        didSet {
            self.reloadImage()
        }
    }

    /// It's usually more convenient when dealing with Quickdraw
    /// coordinates to make this view display flipped.
    override var isFlipped: Bool { true }

    @objc var x: CGFloat {
        get { rawFrame.origin.x }
        set {
            undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
            rawFrame.origin.x = newValue
        }
    }
    @objc var y: CGFloat {
        get { rawFrame.origin.y }
        set {
            undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
            rawFrame.origin.y = newValue
        }
    }
    @objc var width: CGFloat {
        get { rawFrame.size.width }
        set {
            undoManager?.setActionName(NSLocalizedString("Resize Item", comment: ""))
            rawFrame.size.width = newValue
        }
    }
    @objc var height: CGFloat {
        get { rawFrame.size.height }
        set {
            undoManager?.setActionName(NSLocalizedString("Resize Item", comment: ""))
            rawFrame.size.height = newValue
        }
    }

    /// The underlying frame, accounting for insets for Edit Text
    var rawFrame: NSRect {
        get {
            if type == .editText {
                frame.insetBy(dx: 3, dy: 3)
            } else {
                frame
            }
        }
        set {
            let oldFrame = rawFrame
            if type == .editText {
                frame = newValue.insetBy(dx: -3, dy: -3)
            } else {
                frame = newValue
            }
            undoManager?.registerUndo(withTarget: self, handler: { $0.rawFrame = oldFrame })
            NotificationCenter.default.post(name: DITLDocumentView.itemFrameDidChangeNotification, object: superview)
        }
    }

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        switch key {
        case "x", "y", "width", "height": ["frame"]
        default: []
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
    
    init(rawFrame: NSRect, title: String, type: DITLItem.DITLItemType, enabled: Bool, resourceID: Int, manager: RFEditorManager) {
        self.title = title
        self.type = type
        self.enabled = enabled
        self.resourceID = resourceID
        self.manager = manager
        super.init(frame: .zero)
        self.rawFrame = rawFrame
        // When building on macOS 14+ this defaults to false.
        clipsToBounds = true
        self.reloadImage()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Load the picture or icon associated with this dialog:
    private func reloadImage() {
        let resource: Resource? = switch type {
        case .picture:
            manager.findResource(type: .picture, id: resourceID)
        case .icon:
            manager.findResource(type: .colorIcon, id: resourceID) ?? manager.findResource(type: .icon, id: resourceID)
        default:
            nil
        }
        if let resource {
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
            if let currEvent {
                switch currEvent.type {
                case .leftMouseDown, .leftMouseUp:
                    keepTracking = false
                case .leftMouseDragged:
                    let currPos = superview!.convert(currEvent.locationInWindow, from: nil)
                    let distance = NSSize(width: currPos.x - lastPos.x, height: currPos.y - lastPos.y)
                    var box = rawFrame
                    if Self.rightEdgeIndices.contains(index) {
                        box.size.width = max(0, box.width + distance.width)
                    } else if Self.leftEdgeIndices.contains(index) {
                        box.size.width = max(0, box.width - distance.width)
                        box.origin.x += distance.width
                    }
                    if Self.bottomEdgeIndices.contains(index) {
                        box.size.height = max(0, box.height + distance.height)
                    } else if Self.topEdgeIndices.contains(index) {
                        box.size.height = max(0, box.height - distance.height)
                        box.origin.y += distance.height
                    }
                    if !didChange {
                        undoManager?.beginUndoGrouping()
                        undoManager?.setActionName(NSLocalizedString("Resize Item", comment: ""))
                        didChange = true
                    }
                    rawFrame = box
                    lastPos = currPos
                default:
                    keepTracking = false
                }
            }
        }
        if didChange {
            rawFrame = rawFrame.rounded
            undoManager?.endUndoGrouping()
        }
    }

    /// Move the view and any other selected views around in response to the user dragging it.
    private func trackDrag(for startEvent: NSEvent) {
        var lastPos = superview!.convert(startEvent.locationInWindow, from: nil)
        var keepTracking = true
        var didChange = false
        let selection = (superview?.subviews as? [DITLItemView] ?? []).filter(\.selected)
        while keepTracking {
            let currEvent = NSApplication.shared.nextEvent(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp], until: Date.distantFuture, inMode: .eventTracking, dequeue: true)
            if let currEvent {
                switch currEvent.type {
                case .leftMouseDown, .leftMouseUp:
                    keepTracking = false
                case .leftMouseDragged:
                    let currPos = superview!.convert(currEvent.locationInWindow, from: nil)
                    let distance = NSSize(width: currPos.x - lastPos.x, height: currPos.y - lastPos.y)
                    if !didChange {
                        undoManager?.beginUndoGrouping()
                        undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
                        didChange = true
                    }
                    for itemView in selection {
                        itemView.rawFrame = itemView.rawFrame.offsetBy(dx: distance.width, dy: distance.height)
                    }
                    lastPos = currPos
                default:
                    keepTracking = false
                }
            }
        }
        if didChange {
            for itemView in selection {
                itemView.rawFrame = itemView.rawFrame.rounded
            }
            undoManager?.endUndoGrouping()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        needsDisplay = true
        if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command) { // Multi-selection.
            NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: superview)
            selected = !selected
            NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: superview)
        } else if selected { // Drag/resize of selected items.
            var knobIndex = 0
            let pos = convert(event.locationInWindow, from: nil)
            for knob in self.calculateKnobRects() {
                if let knob, knob.contains(pos) {
                    self.trackKnob(knobIndex, for: event)
                    return
                }
                knobIndex += 1
            }
            if (event.clickCount % 2) == 0 {
                NotificationCenter.default.post(name: DITLDocumentView.itemDoubleClickedNotification, object: superview, userInfo: [DITLDocumentView.doubleClickedItemView: self])
            } else {
                self.trackDrag(for: event)
            }
        } else { // Select and possibly drag around an unselected item:
            NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: superview)
            let selection = (superview?.subviews as? [DITLItemView] ?? []).filter(\.selected)
            for itemView in selection {
                itemView.selected = false
                itemView.needsDisplay = true
            }
            selected = true
            NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: superview)
            if (event.clickCount % 2) == 0 {
                NotificationCenter.default.post(name: DITLDocumentView.itemDoubleClickedNotification, object: superview, userInfo: [DITLDocumentView.doubleClickedItemView: self])
            } else {
                self.trackDrag(for: event)
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
            NSBezierPath.fill(bounds)
            NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
        case .button:
            let fillColor = NSColor.white
            let strokeColor = NSColor.black
            fillColor.setFill()
            strokeColor.setStroke()
            let lozenge = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8.0, yRadius: 8.0)
            lozenge.fill()
            lozenge.stroke()
            
            let ps = NSMutableParagraphStyle()
            ps.alignment = .center
            ps.lineBreakMode = .byTruncatingTail
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: strokeColor, .paragraphStyle: ps,
                .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0) ?? .systemFont(ofSize: 12)
            ]
            let measuredSize = title.size(withAttributes: attrs)
            var textBox = bounds
            textBox.origin.y += (textBox.size.height - measuredSize.height) / 2.0
            textBox.size.height = measuredSize.height
            title.draw(in: textBox, withAttributes: attrs)
        case .checkBox:
            let fillColor = NSColor.white
            let strokeColor = NSColor.black
            fillColor.setFill()
            strokeColor.setStroke()
            var box = bounds
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
            var box = bounds
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
            NSBezierPath.fill(bounds)
            NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
        case .staticText:
            title.draw(in: bounds, withAttributes: [.foregroundColor: NSColor.black, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
        case .editText:
            let fillColor = NSColor.white
            let strokeColor = NSColor.black
            fillColor.setFill()
            strokeColor.setStroke()
            NSBezierPath.fill(bounds)
            NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))

            title.draw(in: bounds.insetBy(dx: 3, dy: 0), withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
        case .icon:
            if let image {
                image.draw(in: bounds, from: .zero, operation: .sourceAtop, fraction: 1.0, respectFlipped: true, hints: nil)
            } else {
                NSColor.darkGray.setFill()
                NSBezierPath.fill(bounds)
            }
        case .picture:
            if let image {
                image.draw(in: bounds, from: .zero, operation: .sourceAtop, fraction: 1.0, respectFlipped: true, hints: nil)
            } else {
                NSColor.darkGray.setFill()
                NSBezierPath.fill(bounds)
            }
        case .helpItem:
            let fillColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
            let strokeColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
            fillColor.setFill()
            strokeColor.setStroke()
            NSBezierPath.fill(bounds)
            NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
        default:
            let fillColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
            let strokeColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
            fillColor.setFill()
            strokeColor.setStroke()
            NSBezierPath.fill(bounds)
            NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))

            title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemRed, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
        }
        
        // Draw selection outline and resize handles, if this view is selected.
        if selected {
            NSColor.controlAccentColor.set()
            NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
            for knob in self.calculateKnobRects() {
                if let knob {
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
        let box = bounds
        var middleKnobs = true
        var minimalKnobs = false
        if ((knobSize * 2.0) + 1) >= box.size.height || ((knobSize * 2.0) + 1) >= box.size.width {
            minimalKnobs = true
        } else if ((knobSize * 3.0) + 2) >= box.size.height || ((knobSize * 3.0) + 2) > box.size.width {
            middleKnobs = false
        } else if (knobSize + 1) > box.size.height || (knobSize + 1) > box.size.width {
            knobSize = min(box.size.height - 1, box.size.width - 1)
        }
        
        var tlBox = bounds
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
}

extension NSRect {
    var rounded: NSRect {
        NSRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(), height: height.rounded())
    }
}
