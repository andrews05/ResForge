import Cocoa

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
    @IBOutlet var controller: ShanWindowController!
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
                guard spriteID > 0, let resource = controller.resource.manager.findResource(ofType: "rlëD", id: Int(spriteID), currentDocumentOnly: false) else {
                    spriteLink.title = "not found"
                    return
                }
                // Base sprite is loaded on the main thread, others are loaded in background
                if type(of: self) == BaseLayer.self {
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
            let rle = try Rle(data)
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
            DispatchQueue.main.async {
                self.spriteLink.title = title
            }
        }
    }
    
    @IBAction func openSprite(_ sender: Any) {
        if let manager = controller.resource.manager {
            if let resource = manager.findResource(ofType: "rlëD", id: Int(spriteID), currentDocumentOnly: false) {
                // If we found a resource but don't currently have any frames, try loading it again
                if frames.isEmpty && !resource.data.isEmpty {
                    self.loadRleAsync(resource.data)
                }
                manager.open(resource: resource, using: nil, template: nil)
            } else {
                manager.createResource(ofType: "rlëD", id: Int(spriteID), name: "")
            }
        }
    }
    
    func draw(_ dirtyRect: NSRect) {
        let alpha = self.alpha
        guard alpha > 0, let bitmap = currentFrame else {
            return
        }
        let rect = NSMakeRect(dirtyRect.midX-(bitmap.size.width/2), dirtyRect.midY-(bitmap.size.height/2), bitmap.size.width, bitmap.size.height)
        bitmap.draw(in: rect, from: NSZeroRect, operation: operation, fraction: alpha, respectFlipped: true, hints: nil)
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        if key != "enabled" {
            controller.setDocumentEdited(true)
        }
    }
}
