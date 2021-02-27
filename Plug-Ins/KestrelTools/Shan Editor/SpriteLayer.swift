import RFSupport
import Cocoa

enum SpriteLayerType: Int {
    case base, alt, engine, light, weapon, shield
}

class SpriteLayer: NSObject {
    var type: SpriteLayerType!
    var frames: [NSBitmapImageRep] = []
    @IBOutlet var controller: ShanWindowController!
    @IBOutlet var spriteLink: NSButton!
    @objc dynamic var spriteID: Int16 = 0 {
        didSet {
            self.loadRle()
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
        let bitmap = frames[controller.currentFrame % frames.count]
        let rect = NSMakeRect(dirtyRect.midX-(bitmap.size.width/2), dirtyRect.midY-(bitmap.size.height/2), bitmap.size.width, bitmap.size.height)
        let operation: NSCompositingOperation
        switch type {
        case .base, .alt:
            operation = .sourceOver
        default:
            operation = .plusLighter
        }
        bitmap.draw(in: rect, from: NSZeroRect, operation: operation, fraction: 1, respectFlipped: true, hints: nil)
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        controller.setDocumentEdited(true)
    }
}
