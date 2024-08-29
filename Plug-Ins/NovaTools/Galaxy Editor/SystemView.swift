import AppKit
import RFSupport

class SystemView: NSView {
    let resource: Resource
    let isEnabled: Bool
    private(set) var position = NSPoint.zero
    private(set) var links: [Int] = []
    private var attributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 11)]
    }
    private var galaxyView: GalaxyView? {
        superview as? GalaxyView
    }
    var showName = true
    var point = NSPoint.zero {
        didSet {
            frame.origin.x = point.x - 6
            frame.origin.y = point.y - 6
        }
    }
    var isHighlighted = false {
        didSet {
            if oldValue != isHighlighted {
                needsDisplay = true
            }
        }
    }
    var highlightCount = 1 {
        didSet {
            if oldValue != highlightCount {
                needsDisplay = true
            }
        }
    }

    init?(_ system: Resource, isEnabled: Bool) {
        resource = system
        self.isEnabled = isEnabled
        super.init(frame: .zero)
        do {
            try self.read()
        } catch {
            return nil
        }
    }

    func read() throws {
        let reader = BinaryDataReader(resource.data)
        position.x = Double(try reader.read() as Int16)
        position.y = Double(try reader.read() as Int16)
        links = try (0..<16).map { _ in
            Int(try reader.read() as Int16)
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
        if let point = (superview as? GalaxyView)?.transform.transform(position) {
            self.point = point
        }
        frame.size.height = 12
        frame.size.width = 12
        if showName {
            let nameBounds = resource.name.boundingRect(with: .zero, attributes: attributes)
            frame.size.width += 2 + nameBounds.width + 4
        }
    }

    func move(to newPos: NSPoint) {
        let curPos = position
        position = NSPoint(x: newPos.x.rounded(), y: newPos.y.rounded())
        self.updateFrame()
        self.save()
        undoManager?.registerUndo(withTarget: self) { $0.move(to: curPos) }
    }

    func addLink(_ id: Int) {
        guard isEnabled, !links.contains(id), let i = links.firstIndex(of: -1) else {
            return
        }
        var links = links
        links[i] = id
        self.setLinks(links)
        undoManager?.setActionName("Add Link")
    }

    func removeLink(_ id: Int) {
        guard isEnabled, links.contains(id) else {
            return
        }
        var links = links
        links.removeAll { $0 == id }
        while links.count < 16 {
            links.append(-1)
        }
        self.setLinks(links)
        undoManager?.setActionName("Remove Link")
    }

    private func setLinks(_ newLinks: [Int]) {
        assert(newLinks.count == 16)
        let curLinks = links
        links = newLinks
        self.save()
        undoManager?.registerUndo(withTarget: self) { $0.setLinks(curLinks) }
    }

    private func save() {
        guard resource.data.count >= 18 * 2 else {
            return
        }
        let writer = BinaryDataWriter()
        writer.data = resource.data
        writer.write(Int16(position.x), at: 0)
        writer.write(Int16(position.y), at: 2)
        var pos = 4
        for link in links {
            writer.write(Int16(link), at: pos)
            pos += 2
        }
        galaxyView?.isSavingSystem = true
        resource.data = writer.data
        galaxyView?.isSavingSystem = false
        galaxyView?.needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard dirtyRect.intersects(bounds) else {
            return
        }

        if isHighlighted {
            // Highlight background
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill()

            // Black circle
            NSColor.black.setFill()
            let circle = NSRect(x: 1, y: 1, width: 10, height: 10)
            NSBezierPath(ovalIn: circle).fill()

            // Count of selected systems at this point
            let countRect = NSRect(x: 3.5, y: 3, width: 0, height: 0)
            "\(highlightCount)".draw(with: countRect, attributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 9)])
        } else {
            NSColor.black.setFill()
            if isEnabled {
                NSColor.blue.setStroke()
            } else {
                NSColor.gray.setStroke()
            }
            let circle = NSRect(x: 2, y: 2, width: 8, height: 8)
            let path = NSBezierPath(ovalIn: circle)
            path.fill()
            path.stroke()
        }

        if showName {
            let rect = NSRect(x: 14, y: 2.5, width: 0, height: 0)
            resource.name.draw(with: rect, attributes: attributes)
        }
    }

    // MARK: - Mouse events

    private var useRightMouse = false

    override func mouseDown(with event: NSEvent) {
        if isEnabled {
            useRightMouse = event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option)
            if useRightMouse {
                galaxyView?.rightMouseDown(system: self, with: event)
            } else {
                galaxyView?.mouseDown(system: self, with: event)
            }
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if isEnabled {
            if useRightMouse {
                galaxyView?.rightMouseDragged(system: self, with: event)
            } else {
                galaxyView?.mouseDragged(system: self, with: event)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        if isEnabled {
            if useRightMouse {
                galaxyView?.rightMouseUp(system: self, with: event)
            } else {
                galaxyView?.mouseUp(system: self, with: event)
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if isEnabled {
            window?.makeKeyAndOrderFront(self)
            galaxyView?.rightMouseDown(system: self, with: event)
        }
    }

    override func rightMouseDragged(with event: NSEvent) {
        if isEnabled {
            galaxyView?.rightMouseDragged(system: self, with: event)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        if isEnabled {
            galaxyView?.rightMouseUp(system: self, with: event)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        galaxyView?.mouseEntered(system: self, with: event)
    }

    override func mouseExited(with event: NSEvent) {
        galaxyView?.mouseExited(system: self, with: event)
    }
}
