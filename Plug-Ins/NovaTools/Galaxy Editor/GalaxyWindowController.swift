import Cocoa
import RFSupport

/*
 * The galaxy editor is a bit hacky. It relies on a set of 2048 dummy 'glxÿ' resources within the
 * support file (one for each possible sÿst) which are opened using RREF links in the sÿst template.
 * The GalaxyStub is the registered editor for this type but all it does is hand over to the shared
 * GalaxyWindowController, passing the id of the glxÿ resource as the id of the system to center on.
 */
class GalaxyStub: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["glxÿ"]
    let resource: Resource
    
    required init?(resource: Resource, manager: RFEditorManager) {
        GalaxyWindowController.shared.show(systemID: resource.id, manager: manager)
        return nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func saveResource(_ sender: Any) {}
    func revertResource(_ sender: Any) {}
}

class GalaxyWindowController: NSWindowController, NSWindowDelegate {
    static var shared = GalaxyWindowController()
    
    @IBOutlet var clipView: NSClipView!
    @IBOutlet var galaxyView: GalaxyView!
    var centerID = 0
    var systems: [Int: (name: String, pos: NSPoint)] = [:]
    var links: [(Int, Int)] = []
    var nebulae: [Int: (name: String, area: NSRect)] = [:]
    var nebImages: [Int: NSImage] = [:]
    
    override var windowNibName: String {
        return "GalaxyWindow"
    }
    
    func show(systemID: Int, manager: RFEditorManager) {
        window?.makeKeyAndOrderFront(self)
        centerID = systemID
        systems = [:]
        links = []
        nebulae = [:]
        nebImages = [:]
        
        let systs = manager.allResources(ofType: ResourceType("sÿst"), currentDocumentOnly: false)
        for system in systs {
            guard systems[system.id] == nil else {
                continue
            }
            let reader = BinaryDataReader(system.data)
            do {
                let point = NSPoint(
                    x: CGFloat(try reader.read() as Int16),
                    y: CGFloat(try reader.read() as Int16)
                )
                systems[system.id] = (system.name, point)
                for _ in 0..<16 {
                    let id = Int(try reader.read() as Int16)
                    links.append((system.id, id))
                }
            } catch {}
        }
        
        let nebus = manager.allResources(ofType: ResourceType("nëbu"), currentDocumentOnly: false)
        for nebu in nebus {
            guard nebulae[nebu.id] == nil else {
                continue
            }
            let reader = BinaryDataReader(nebu.data)
            do {
                let rect = NSRect(
                    x: CGFloat(try reader.read() as Int16),
                    y: CGFloat(try reader.read() as Int16),
                    width: CGFloat(try reader.read() as Int16),
                    height: CGFloat(try reader.read() as Int16)
                )
                nebulae[nebu.id] = (nebu.name, rect)
                let first = (nebu.id - 128) * 7 + 9500
                for id in (first..<first+7).reversed() {
                    if let pict = manager.findResource(type: ResourceType("PICT"), id: id, currentDocumentOnly: false) {
                        pict.preview {
                            self.nebImages[nebu.id] = $0
                            self.galaxyView.needsDisplay = true
                        }
                    }
                }
            } catch {}
        }
        
        var point = galaxyView.transform.transform(systems[centerID]?.pos ?? NSZeroPoint)
        point.x -= clipView.frame.midX
        point.y = galaxyView.frame.height - point.y - clipView.frame.midY
        galaxyView.scroll(point)
        galaxyView.needsDisplay = true
    }
}

extension NSPoint: Hashable, Comparable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
    }
    
    public static func < (lhs: CGPoint, rhs: CGPoint) -> Bool {
        lhs.x < rhs.x && lhs.y < rhs.y
    }
}
