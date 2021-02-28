import RFSupport
import Cocoa

class SpriteLayer: NSObject {
    var frames: [NSBitmapImageRep] = []
    var alpha: CGFloat = 1
    var operation: NSCompositingOperation { .plusLighter }
    @IBOutlet var controller: ShanWindowController!
    @IBOutlet var spriteLink: NSButton!
    @objc var enabled = true {
        didSet {
            alpha = enabled ? 1 : 0
        }
    }
    @objc dynamic var spriteID: Int16 = 0 {
        didSet {
            self.loadRle()
            controller.setDocumentEdited(true)
        }
    }
    
    func load(_ shan: Shan) {
    }
    
    func nextFrame() {
    }
    
    func loadRle() {
        frames.removeAll()
        guard spriteID > 0, let rleResource = controller.resource.manager.findResource(ofType: "rlëD", id: Int(spriteID), currentDocumentOnly: false) else {
            spriteLink.title = "not found"
            return
        }
        do {
            let rle = try Rle(rleResource.data)
            for _ in 0..<rle.frameCount {
                frames.append(try rle.readFrame())
            }
            spriteLink.title = "\(rle.frameWidth)x\(rle.frameHeight), \(rle.frameCount)"
        } catch {
            frames.removeAll()
            spriteLink.title = "error"
        }
    }
    
    @IBAction func openSprite(_ sender: Any) {
        if let manager = controller.resource.manager {
            if let rleResource = manager.findResource(ofType: "rlëD", id: Int(spriteID), currentDocumentOnly: false) {
                manager.open(resource: rleResource, using: nil, template: nil)
            } else {
                manager.createResource(ofType: "rlëD", id: Int(spriteID), name: "")
            }
        }
    }
    
    func draw(_ dirtyRect: NSRect) {
        let alpha = self.alpha
        guard alpha > 0 && !frames.isEmpty else {
            return
        }
        let bitmap = frames[controller.currentFrame % frames.count]
        let rect = NSMakeRect(dirtyRect.midX-(bitmap.size.width/2), dirtyRect.midY-(bitmap.size.height/2), bitmap.size.width, bitmap.size.height)
        bitmap.draw(in: rect, from: NSZeroRect, operation: operation, fraction: alpha, respectFlipped: true, hints: nil)
    }
}
