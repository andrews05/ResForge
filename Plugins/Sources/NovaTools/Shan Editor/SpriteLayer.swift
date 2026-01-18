import AppKit
import RFSupport

class SpriteLayer: NSObject {
    // Nova has 32 levels of transparency, generally given in the range 1-32. To keep things simple we allow 0-32.
    static let TransparencyStep: CGFloat = 1/32

    var frames: [NSBitmapImageRep] = []
    var operation: NSCompositingOperation { .plusLighter }
    var alpha: CGFloat = 1
    var currentFrame: NSBitmapImageRep? {
        guard frames.count > 0 else {
            return nil
        }
        let index = (controller.framesPerSet * controller.currentSet) + controller.currentFrame
        return frames[index % frames.count]
    }
    @IBOutlet weak var controller: ShanWindowController!
    @IBOutlet var spriteLink: NSButton!
    @objc var enabled = true {
        didSet {
            alpha = enabled ? 1 : 0
        }
    }
    @objc dynamic var spriteID: Int16 = -1 {
        didSet {
            if spriteID != oldValue {
                frames.removeAll()
                guard spriteID > 0, let resource = controller.manager.findResource(type: .rle16, id: Int(spriteID)) else {
                    spriteLink.title = "not found"
                    spriteLink.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: nil)
                    return
                }
                spriteLink.image = NSImage(systemSymbolName: "arrow.right.circle", accessibilityDescription: nil)
                // Base sprite is loaded on the main thread, others are loaded in background
                if Self.self == BaseLayer.self {
                    spriteLink.title = self.loadRle(resource.data)
                } else {
                    self.loadRleAsync(resource.data)
                }
            }
        }
    }
    // These are only for PICT sprites and are unused here
    var maskID: Int16 = -1
    var width: Int16 = 0
    var height: Int16 = 0

    func nextFrame() {
        // Subclasses override to perform any necessary calculations
    }

    private func loadRle(_ data: Data) -> String {
        do {
            let rle = try SpriteWorld(data)
            var frameList: [NSBitmapImageRep] = []
            for _ in 0..<rle.frameCount {
                frameList.append(try rle.readFrame())
            }
            frames = frameList
            return "\(rle.frameCount)@\(rle.frameWidth)x\(rle.frameHeight)"
        } catch {
            return "error"
        }
    }

    private func loadRleAsync(_ data: Data) {
        spriteLink.title = "loading…"
        DispatchQueue.global().async {
            let title = self.loadRle(data)
            DispatchQueue.main.async { [self] in
                spriteLink.title = title
                // If this is the base layer and framePerSet has not been set yet, set it automatically
                if Self.self == BaseLayer.self && controller.framesPerSet == 0 && controller.setCount != 0 {
                    controller.framesPerSet = frames.count / controller.setCount
                }
            }
        }
    }

    @IBAction func openSprite(_ sender: Any) {
        guard controller.window?.makeFirstResponder(nil) != false else {
            return
        }
        if let resource = controller.manager.findResource(type: .rle16, id: Int(spriteID)) {
            // If we found a resource but don't currently have any frames, try loading it again
            if frames.isEmpty && !resource.data.isEmpty {
                self.loadRleAsync(resource.data)
            }
            controller.manager.open(resource: resource)
        } else {
            controller.manager.createResource(type: .rle16, id: Int(spriteID)) { [weak self] resource in
                guard let self else { return }
                // Update the field if the resource was created with a different id,
                // but avoid marking the window as dirty if it is the same
                let newID = Int16(resource.id)
                if self.spriteID != newID {
                    self.spriteID = newID
                }
                // The resource will be empty on initial creation - add an observer to load it when the data changes
                NotificationCenter.default.addObserver(self, selector: #selector(self.rleCreated(_:)), name: .ResourceDataDidChange, object: resource)
            }
        }
    }

    @objc private func rleCreated(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self, name: .ResourceDataDidChange, object: nil)
        guard let resource = notification.object as? Resource, resource.id == spriteID else {
            return
        }
        self.loadRleAsync(resource.data)
    }

    func draw(_ dirtyRect: NSRect) {
        let alpha = self.alpha
        guard alpha > 0, let bitmap = currentFrame else {
            return
        }
        let rect = NSRect(x: dirtyRect.midX-(bitmap.size.width/2), y: dirtyRect.midY-(bitmap.size.height/2), width: bitmap.size.width, height: bitmap.size.height)
        bitmap.draw(in: rect, from: .zero, operation: operation, fraction: alpha, respectFlipped: true, hints: nil)
    }

    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        if key != "enabled" {
            controller.setDocumentEdited(true)
        }
    }
}
