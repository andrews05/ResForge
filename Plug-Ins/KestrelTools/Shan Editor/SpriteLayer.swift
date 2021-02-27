import RFSupport
import Cocoa

enum SpriteLayerType: Int {
    case base, alt, engine, light, weapon, shield
}

class SpriteLayer: NSObject {
    var type: SpriteLayerType!
    var frames: [NSBitmapImageRep] = []
    var alpha: CGFloat = 1
    @IBOutlet var controller: ShanWindowController!
    @IBOutlet var spriteLink: NSButton!
    @objc var enabled = true
    @objc dynamic var spriteID: Int16 = 0 {
        didSet {
            self.loadRle()
            controller.setDocumentEdited(true)
        }
    }
    
    func load() {
        switch type {
        case .base:
            spriteID = controller.shan.baseSprite
        case .alt:
            spriteID = controller.shan.altSprite
        case .engine:
            spriteID = controller.shan.engineSprite
        case .light:
            spriteID = controller.shan.lightSprite
        case .weapon:
            spriteID = controller.shan.weaponSprite
        case .shield:
            spriteID = controller.shan.shieldSprite
        default:
            break
        }
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
        guard !frames.isEmpty else {
            return
        }
        let fraction: CGFloat
        if type == .engine {
            if enabled && alpha < 1 {
                alpha += 1/30
            } else if !enabled && alpha > 0 {
                alpha -= 1/30
            }
            fraction = alpha + CGFloat.random(in: -0.2..<0)
        } else {
            fraction = enabled ? 1 : 0
        }
        guard fraction > 0 else {
            return
        }
        let bitmap = frames[controller.currentFrame % frames.count]
        let rect = NSMakeRect(dirtyRect.midX-(bitmap.size.width/2), dirtyRect.midY-(bitmap.size.height/2), bitmap.size.width, bitmap.size.height)
        let operation: NSCompositingOperation
        switch type {
        case .base, .alt:
            operation = .sourceOver
        default:
            operation = .plusLighter
        }
        bitmap.draw(in: rect, from: NSZeroRect, operation: operation, fraction: fraction, respectFlipped: true, hints: nil)
    }
}
