import AppKit
import RFSupport

class ItemView: NSView {
    let resource: Resource
    let manager: RFEditorManager
    let isEnabled: Bool
    var isHighlighted = false {
        didSet {
            if oldValue != isHighlighted {
                needsDisplay = true
            }
        }
    }
    var point = NSPoint.zero

    init?(_ resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        isEnabled = resource.document == manager.document
        super.init(frame: .zero)
        do {
            try self.read()
        } catch {
            return nil
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func read() throws {}
    func updateFrame() {}
    func move(to point: NSPoint) {}
}
