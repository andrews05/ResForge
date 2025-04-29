import AppKit
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/MacintoshToolboxEssentials.pdf#777
// https://dev.os9.ca/techpubs/mac/Toolbox/Toolbox-438.html

@objc enum DITLItemType: UInt8 {
    case userItem = 0
    case helpItem = 1
    case button = 4
    case checkBox = 5
    case radioButton = 6
    case control = 7
    case staticText = 8
    case editText = 16
    case icon = 32
    case picture = 64
    case unknown = 255

    var name: String {
        switch self {
        case .userItem: "User Item"
        case .helpItem: "Help Item"
        case .button: "Button"
        case .checkBox: "Check Box"
        case .radioButton: "Radio Button"
        case .control: "Control"
        case .staticText: "Static Text"
        case .editText: "Edit Text"
        case .icon: "Icon"
        case .picture: "Picture"
        case .unknown: "Unknown"
        }
    }
}

@objc enum DITLHelpItemType: UInt16 {
    case unknown = 0
    case HMScanhdlg = 1
    case HMScanhrct = 2
    case HMScanAppendhdlg = 8
}

/// View that shows a simple preview for a System 7 DITL item:
/// This view must be an immediate subview of a ``DITLDocumentView``.
class DITLItemView: NSView {
    private let rightEdgeIndices = [0, 1, 2]
    private let leftEdgeIndices = [4, 5, 6]
    private let bottomEdgeIndices = [0, 6, 7]
    private let topEdgeIndices = [2, 3, 4]
    // Krungthep is a Thai font where the latin characters are from the old Chicago.
    // Mac OS 8/9 actually use Charcoal but this is no longer included in any form.
    private let font = NSFontManager.shared.font(withFamily: "Krungthep", traits: [], weight: 0, size: 12.0) ?? .systemFont(ofSize: 12)

    /// It's usually more convenient when dealing with Quickdraw
    /// coordinates to make this view display flipped.
    override var isFlipped: Bool { true }
    override var clipsToBounds: Bool {
        get { true }
        set { }
    }

    /// Object that lets us look up icons and images.
    private let manager: RFEditorManager
    private var controller: DialogEditor? {
        window?.windowController as? DialogEditor
    }

    @objc var x: CGFloat {
        get { rawFrame.origin.x }
        set {
            rawFrame.origin.x = newValue
            undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
        }
    }
    @objc var y: CGFloat {
        get { rawFrame.origin.y }
        set {
            rawFrame.origin.y = newValue
            undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
        }
    }
    @objc var width: CGFloat {
        get { rawFrame.size.width }
        set {
            rawFrame.size.width = newValue
            undoManager?.setActionName(NSLocalizedString("Resize Item", comment: ""))
        }
    }
    @objc var height: CGFloat {
        get { rawFrame.size.height }
        set {
            rawFrame.size.height = newValue
            undoManager?.setActionName(NSLocalizedString("Resize Item", comment: ""))
        }
    }

    /// Info from the DITL resource about this item:
    @objc dynamic var type: DITLItemType {
        didSet {
            self.reloadImage()
            undoManager?.setActionName(NSLocalizedString("Change Item Type", comment: ""))
            undoManager?.registerUndo(withTarget: self) { $0.type = oldValue }
            controller?.setDocumentEdited(true)
            controller?.reflectSelectedItem()
        }
    }
    /// Is this item clickable?
    @objc dynamic var enabled = true {
        didSet {
            let action = enabled ? "Enable Item" : "Disable Item"
            undoManager?.setActionName(NSLocalizedString(action, comment: ""))
            undoManager?.registerUndo(withTarget: self) { $0.enabled = oldValue }
            controller?.setDocumentEdited(true)
        }
    }
    /// The text to display on the item (button title or text view text:
    @objc dynamic var text = "" {
        didSet {
            needsDisplay = true
            undoManager?.setActionName(NSLocalizedString("Change Item Text", comment: ""))
            undoManager?.registerUndo(withTarget: self) { $0.text = oldValue }
            controller?.setDocumentEdited(true)
        }
    }
    /// Resource referenced by this item (e.g. ICON ID for an icon item PICT for picture, CNTL for control etc.)
    @objc dynamic var resourceID = 0 {
        didSet {
            self.reloadImage()
            undoManager?.setActionName(NSLocalizedString("Change Item Resource ID", comment: ""))
            undoManager?.registerUndo(withTarget: self) { $0.resourceID = oldValue }
            controller?.setDocumentEdited(true)
        }
    }
    @objc dynamic var helpItemType = DITLHelpItemType.HMScanhdlg {
        didSet {
            undoManager?.setActionName(NSLocalizedString("Change Item Help Type", comment: ""))
            undoManager?.registerUndo(withTarget: self) { $0.helpItemType = oldValue }
            controller?.setDocumentEdited(true)
        }
    }
    @objc dynamic var helpItemNumber: Int16 = 0 {
        didSet {
            undoManager?.setActionName(NSLocalizedString("Change Item Help Item", comment: ""))
            undoManager?.registerUndo(withTarget: self) { $0.helpItemNumber = oldValue }
            controller?.setDocumentEdited(true)
        }
    }

    /// Binding to show/hide the item number field
    @objc var hasItemNumber: Bool {
        helpItemType == .HMScanAppendhdlg
    }

    /// Is this object selected for editing/moving/resizing?
    var selected = false {
        didSet {
            needsDisplay = true
        }
    }

    private var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    /// The underlying frame, accounting for insets for Edit Text
    private var rawFrame: NSRect {
        get { self.convert(frame) }
        set {
            let oldFrame = rawFrame
            frame = self.convert(newValue, inverse: true)
            undoManager?.registerUndo(withTarget: self) { $0.rawFrame = oldFrame }
            controller?.setDocumentEdited(true)
            (superview as? DITLDocumentView)?.updateMinSize()
        }
    }

    override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        switch key {
        case "x", "y", "width", "height": ["frame"]
        case "hasItemNumber": ["helpItemType"]
        default: []
        }
    }

    init(_ reader: BinaryDataReader, manager: RFEditorManager) throws {
        try reader.advance(4)
        let t = Int(try reader.read() as Int16)
        let l = Int(try reader.read() as Int16)
        let b = Int(try reader.read() as Int16)
        let r = Int(try reader.read() as Int16)
        let rawType: UInt8 = try reader.read()
        enabled = (rawType & 0b10000000) == 0
        type = DITLItemType(rawValue: rawType & 0b01111111) ?? .unknown

        switch type {
        case .checkBox, .radioButton, .button, .staticText:
            text = try reader.readPString()
        case .editText:
            text = try reader.readPString()
        case .control, .icon, .picture:
            try reader.advance(1)
            resourceID = Int(try reader.read() as Int16)
        case .helpItem:
            try reader.advance(1)
            helpItemType = DITLHelpItemType(rawValue: try reader.read()) ?? .unknown
            resourceID = Int(try reader.read() as Int16)
            if helpItemType == .HMScanAppendhdlg {
                helpItemNumber = try reader.read()
            }
        case .userItem:
            let reserved: UInt8 = try reader.read()
            try reader.advance(Int(reserved))
        default:
            let reserved: UInt8 = try reader.read()
            try reader.advance(Int(reserved))
        }
        if (reader.bytesRead % 2) != 0 {
            try reader.advance(1)
        }

        self.manager = manager
        super.init(frame: .zero)
        rawFrame = NSRect(x: l, y: t, width: r - l, height: b - t)
        self.reloadImage()
    }

    init(frame: NSRect, text: String, type: DITLItemType, manager: RFEditorManager) {
        self.text = text
        self.type = type
        self.manager = manager
        super.init(frame: frame)
    }

    func write(to writer: BinaryDataWriter) throws {
        writer.advance(4)
        let box = rawFrame

        writer.write(Int16(clamping: Int(box.minY)))
        writer.write(Int16(clamping: Int(box.minX)))
        writer.write(Int16(clamping: Int(box.maxY)))
        writer.write(Int16(clamping: Int(box.maxX)))
        writer.write(UInt8(type.rawValue | (enabled ? 0b10000000 : 0)))

        switch type {
        case .checkBox, .radioButton, .button, .staticText, .editText:
            try writer.writePString(text)
        case .control, .icon, .picture:
            writer.write(UInt8(2))
            writer.write(Int16(resourceID))
        case .helpItem:
            writer.write(UInt8((helpItemType == .HMScanAppendhdlg) ? 6 : 4))
            writer.write(helpItemType.rawValue)
            writer.write(Int16(resourceID))
            if helpItemType == .HMScanAppendhdlg {
                writer.write(Int16(helpItemNumber))
            }
        case .userItem:
            writer.write(UInt8(0))
        default:
            writer.write(UInt8(0))
        }
        if (writer.bytesWritten % 2) != 0 {
            writer.advance(1)
        }
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
            }
        } else {
            self.image = nil
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.convert(bounds)
        switch type {
        case .userItem:
            self.colorBox(.systemBlue.withAlphaComponent(0.7), in: bounds)
        case .button:
            NSColor.white.setFill()
            NSColor.black.setStroke()
            let lozenge = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
            lozenge.fill()
            lozenge.stroke()

            let ps = NSMutableParagraphStyle()
            ps.alignment = .center
            ps.lineBreakMode = .byClipping
            let attrs: [NSAttributedString.Key: Any] = [.paragraphStyle: ps, .font: font]
            let measuredSize = text.size(withAttributes: attrs)
            var textBox = bounds
            textBox.origin.y += floor((textBox.size.height - measuredSize.height) / 2.0)
            textBox.size.height = measuredSize.height
            text.draw(in: textBox, withAttributes: attrs)
        case .checkBox:
            let box = NSRect(x: bounds.minX + 2, y: round(bounds.midY - 6), width: 12, height: 12)
            NSColor.white.setFill()
            box.fill()
            NSColor.black.setFill()
            box.frame()

            text.draw(at: NSPoint(x: box.maxX + 5, y: box.minY - 2), withAttributes: [.font: font])
        case .radioButton:
            NSColor.white.setFill()
            NSColor.black.setStroke()
            let box = NSRect(x: bounds.minX + 2, y: round(bounds.midY - 6), width: 12, height: 12)
            let lozenge = NSBezierPath(ovalIn: box.insetBy(dx: 0.5, dy: 0.5))
            lozenge.fill()
            lozenge.stroke()

            text.draw(at: NSPoint(x: box.maxX + 5, y: box.minY - 2), withAttributes: [.font: font])
        case .control:
            self.colorBox(.systemGray, in: bounds)
        case .staticText:
            text.draw(in: bounds, withAttributes: [.font: font])
        case .editText:
            NSColor.white.setFill()
            self.bounds.fill()
            NSColor.black.setFill()
            self.bounds.frame()

            text.draw(in: bounds, withAttributes: [.font: font])
        case .icon, .picture:
            if let image {
                image.draw(in: bounds)
            } else {
                self.colorBox(.systemYellow, in: bounds)
            }
        case .helpItem:
            self.colorBox(.systemGreen, in: bounds)
        default:
            self.colorBox(.systemRed, in: bounds)
            text.draw(at: .zero, withAttributes: [.foregroundColor: NSColor.systemRed, .font: font])
        }

        // Draw selection outline and resize handles, if this view is selected.
        if selected {
            NSColor.controlAccentColor.set()
            bounds.frame()
            for knob in self.calculateKnobRects() {
                knob?.fill()
            }
        }
    }

    private func colorBox(_ color: NSColor, in rect: NSRect) {
        color.highlight(withLevel: 0.4)?.setFill()
        rect.fill()
        color.shadow(withLevel: 0.4)?.setFill()
        rect.frame()
    }

    // MARK: - Moving/resizing

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(superview)
        if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command) { // Multi-selection.
            selected = !selected
            controller?.selectionDidChange()
        } else if selected { // Drag/resize of selected items.
            let pos = convert(event.locationInWindow, from: nil)
            for (i, knob) in self.calculateKnobRects().enumerated() {
                if let knob, knob.contains(pos) {
                    self.trackKnob(i, for: event)
                    return
                }
            }
            self.trackDrag(for: event)
        } else { // Select and possibly drag around an unselected item:
            let selection = (superview?.subviews as? [DITLItemView] ?? []).filter(\.selected)
            for itemView in selection {
                itemView.selected = false
            }
            selected = true
            controller?.selectionDidChange()
            self.trackDrag(for: event)
        }
    }

    /// Resize the view in response to a click on one of the 8 "handles":
    private func trackKnob(_ index: Int, for startEvent: NSEvent) {
        var lastPos = superview!.convert(startEvent.locationInWindow, from: nil)
        var didChange = false
        while let currEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]),
              currEvent.type == .leftMouseDragged {
            let currPos = superview!.convert(currEvent.locationInWindow, from: nil)
            let distance = NSSize(width: currPos.x - lastPos.x, height: currPos.y - lastPos.y)
            var box = rawFrame
            if rightEdgeIndices.contains(index) {
                box.size.width = max(0, box.width + distance.width)
            } else if leftEdgeIndices.contains(index) {
                box.size.width = max(0, box.width - distance.width)
                box.origin.x += distance.width
            }
            if bottomEdgeIndices.contains(index) {
                box.size.height = max(0, box.height + distance.height)
            } else if topEdgeIndices.contains(index) {
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
        }
        if didChange {
            rawFrame = rawFrame.rounded
            undoManager?.endUndoGrouping()
        }
    }

    /// Move the view and any other selected views around in response to the user dragging it.
    private func trackDrag(for startEvent: NSEvent) {
        var lastPos = superview!.convert(startEvent.locationInWindow, from: nil)
        var didChange = false
        let selection = (superview?.subviews as? [DITLItemView] ?? []).filter(\.selected)
        while let currEvent = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]),
              currEvent.type == .leftMouseDragged {
            let currPos = superview!.convert(currEvent.locationInWindow, from: nil)
            let distance = NSSize(width: currPos.x - lastPos.x, height: currPos.y - lastPos.y)
            if !didChange {
                undoManager?.beginUndoGrouping()
                undoManager?.setActionName(NSLocalizedString("Move Item", comment: ""))
                didChange = true
            }
            for item in selection {
                item.rawFrame = item.rawFrame.offsetBy(dx: distance.width, dy: distance.height)
            }
            lastPos = currPos
        }
        if didChange {
            for item in selection {
                item.rawFrame = item.rawFrame.rounded
            }
            undoManager?.endUndoGrouping()
        }
    }
    
    /// Calculate the rects of all 8 resize knobs.
    /// - Returns: An array with an entry for each knob, starting at the lower right,
    /// 		  then continuing counter-clockwise. If this view's rectangle is too
    /// 		  small, some knobs are set to `nil`, to make as many fit as possible.
    private func calculateKnobRects() -> [NSRect?] {
        var result: [NSRect?] = Array(repeating: nil, count: 8)
        var knobSize = 8.0
        let box = self.convert(bounds)
        var middleKnobs = true
        var minimalKnobs = false
        if ((knobSize * 2) + 1) >= box.height || ((knobSize * 2) + 1) >= box.width {
            minimalKnobs = true
        } else if ((knobSize * 3) + 2) >= box.height || ((knobSize * 3) + 2) > box.width {
            middleKnobs = false
        } else if (knobSize + 1) > box.height || (knobSize + 1) > box.width {
            knobSize = min(box.height - 1, box.width - 1)
        }
        
        var tlBox = NSRect()
        tlBox.size.width = knobSize
        tlBox.size.height = knobSize
        tlBox.origin.x = box.maxX - tlBox.width
        tlBox.origin.y = box.maxY - tlBox.height
        result[0] = tlBox
        if !minimalKnobs {
            if middleKnobs {
                tlBox.origin.x = box.maxX - tlBox.width
                tlBox.origin.y = box.midY - (tlBox.height / 2)
                result[1] = tlBox
            }
            tlBox.origin.x = box.maxX - tlBox.width
            tlBox.origin.y = box.minY
            result[2] = tlBox
            if middleKnobs {
                tlBox.origin.x = box.midX - (tlBox.width / 2)
                tlBox.origin.y = box.minY
                result[3] = tlBox
            }
            tlBox.origin.x = box.minX
            tlBox.origin.y = box.minY
            result[4] = tlBox
            if middleKnobs {
                tlBox.origin.x = box.minX
                tlBox.origin.y = box.midY - (tlBox.height / 2)
                result[5] = tlBox
            }
            tlBox.origin.x = box.minX
            tlBox.origin.y = box.maxY - tlBox.height
            result[6] = tlBox
            if middleKnobs {
                tlBox.origin.x = box.midX - (tlBox.width / 2)
                tlBox.origin.y = box.maxY - tlBox.height
                result[7] = tlBox
            }
        }
        
        return result
    }

    private func convert(_ rect: NSRect, inverse: Bool = false) -> NSRect {
        if type == .editText {
            rect.insetBy(dx: inverse ? -3 : 3, dy: inverse ? -3 : 3)
        } else {
            rect
        }
    }
}

extension NSRect {
    var rounded: NSRect {
        NSRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(), height: height.rounded())
    }
}
