import AppKit
import RFSupport

class StellarView: NSView {
    let resource: Resource
    let manager: RFEditorManager
    let isEnabled: Bool
    private(set) var position = NSPoint.zero
    private(set) var image: NSImage? = nil
    private let nameView = NSTextField(labelWithString: "")
    private var systemView: SystemMapView? {
        superview as? SystemMapView
    }
    var point = NSPoint.zero {
        didSet {
            frame.center = point
        }
    }
    var isHighlighted = false {
        didSet {
            if oldValue != isHighlighted {
                needsDisplay = true
            }
        }
    }

    init?(_ stellar: Resource, manager: RFEditorManager, isEnabled: Bool) {
        self.resource = stellar
        self.manager = manager
        self.isEnabled = isEnabled
        super.init(frame: .zero)
        do {
            try self.read()
        } catch {
            return nil
        }

        // To display content outside the frame on macOS < 14, we must use a subview and explicitly set clipsToBounds to false
        // The stellar view itself will always be clipped on macOS < 14
        clipsToBounds = false
        nameView.isHidden = true
        nameView.textColor = .white
        nameView.font = .systemFont(ofSize: 11)
        nameView.wantsLayer = true
        nameView.layer?.cornerRadius = 2
        nameView.layer?.backgroundColor = CGColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.7)
        self.addSubview(nameView)
    }

    func read() throws {
        let reader = BinaryDataReader(resource.data)
        position.x = Double(try reader.read() as Int16)
        position.y = Double(try reader.read() as Int16)
        let spinId = Int(try reader.read() as Int16) + 1000
        try? self.loadGraphic(spinId)
    }

    private func loadGraphic(_ spinId: Int) throws {
        if let spinResource = manager.findResource(type: .spin, id: spinId) {
            let spinReader = BinaryDataReader(spinResource.data)
            let spriteId = Int(try spinReader.read() as Int16)

            // Use the preview provider to obtain an NSImage from the resources the spïn might point to -- try rlëD then fall back to PICT
            if let spriteResource = manager.findResource(type: .rle16, id: spriteId) ?? manager.findResource(type: .picture, id: spriteId) {
                spriteResource.preview { img in
                    self.image = img
                    self.updateFrame()
                    self.needsDisplay = true
                }
            }
        }
    }

    override func updateTrackingAreas() {
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        let tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .enabledDuringMouseDrag], owner: self, userInfo: nil)
        self.addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateFrame() {
        let baseSize = image?.size ?? NSSize(width: 80, height: 80)
        if let size = systemView?.transform.transform(baseSize) {
            // Allow 1px padding for the selection highlight
            frame.size.width = max(size.width, 8) + 2
            frame.size.height = max(size.height, 8) + 2
        }
        if let point = systemView?.transform.transform(position) {
            self.point = point
        }
        self.updateNameView()
        nameView.frame.origin.x = bounds.maxX + 1
        nameView.frame.origin.y = bounds.midY - nameView.frame.height / 2
    }

    func setPoint(_ point: NSPoint, snapSize: Double? = nil) {
        guard isEnabled else { return }
        self.point = point
        if let snapSize {
            // Snap the frame center to a multiple of the value
            frame.center.x = (frame.midX / snapSize).rounded() * snapSize
            frame.center.y = (frame.midY / snapSize).rounded() * snapSize
        }
        self.updateNameView()
    }

    func move(to newPos: NSPoint) {
        guard isEnabled else { return }
        let curPos = position
        position = NSPoint(x: newPos.x.rounded(), y: newPos.y.rounded())
        self.updateFrame()
        self.save()
        undoManager?.registerUndo(withTarget: self) { $0.move(to: curPos) }
    }

    private func save() {
        guard resource.data.count >= 2 * 2 else {
            return
        }
        let writer = BinaryDataWriter()
        writer.data = resource.data
        writer.write(Int16(position.x), at: 0)
        writer.write(Int16(position.y), at: 2)
        systemView?.isSavingStellar = true
        resource.data = writer.data
        systemView?.isSavingStellar = false
    }

    override func draw(_ dirtyRect: NSRect) {
        guard dirtyRect.intersects(bounds) else {
            return
        }

        if let image {
            image.draw(in: bounds.insetBy(dx: 1, dy: 1))
        } else {
            NSColor.black.setFill()
            if isEnabled {
                NSColor.blue.setStroke()
            } else {
                NSColor.gray.setStroke()
            }
            let path = NSBezierPath(ovalIn: bounds.insetBy(dx: 2, dy: 2))
            path.fill()
            path.stroke()
        }

        if isHighlighted {
            // Draw a highlighted outline around the stellar
            if isEnabled {
                NSColor.selectedContentBackgroundColor.setStroke()
            } else {
                NSColor.darkGray.setStroke()
            }
            let outline = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            outline.lineWidth = 2
            outline.stroke()
        }
    }

    private func updateNameView() {
        // Get position from frame center in case the stellar is being moved
        if let position = systemView?.transform.inverted()?.transform(frame.center) {
            let x = Int(position.x.rounded())
            let y = Int(position.y.rounded())
            nameView.stringValue = "\(resource.name): \(x),\(y)"
            nameView.sizeToFit()
        }
    }

    // MARK: - Mouse events

    override func mouseDown(with event: NSEvent) {
        systemView?.mouseDown(stellar: self, with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if isEnabled {
            systemView?.mouseDragged(stellar: self, with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isEnabled {
            systemView?.mouseUp(stellar: self, with: event)
        }
    }

    // Show name on hover
    override func mouseEntered(with event: NSEvent) {
        nameView.isHidden = false
    }
    override func mouseExited(with event: NSEvent) {
        nameView.isHidden = true
    }
}
