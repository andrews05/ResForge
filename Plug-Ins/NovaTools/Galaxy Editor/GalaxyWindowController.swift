import Cocoa
import RFSupport

/*
 * The galaxy editor is a bit hacky. It relies on a set of 2048 dummy 'glxÿ' resources within the
 * support file (one for each possible sÿst) which are opened using RREF links in the sÿst template.
 * The GalaxyStub is the registered editor for this type but all it does is hand over to the shared
 * GalaxyWindowController, passing the id of the glxÿ resource as the id of the system to highlight.
 */
class GalaxyStub: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["glxÿ"]
    let resource: Resource

    required init?(resource: Resource, manager: RFEditorManager) {
        GalaxyWindowController.shared.show(targetID: resource.id, manager: manager)
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
    var targetID = 0
    var systems: [Int: (name: String, pos: NSPoint, links: [Int])] = [:]
    var nebulae: [Int: (name: String, area: NSRect)] = [:]
    var nebImages: [Int: NSImage] = [:]

    override var windowNibName: String {
        return "GalaxyWindow"
    }

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(resourceChanged(_:)), name: .ResourceDidChange, object: nil)
    }

    @IBAction func zoomIn(_ sender: Any) {
        galaxyView.zoomIn(sender)
    }

    @IBAction func zoomOut(_ sender: Any) {
        galaxyView.zoomOut(sender)
    }

    @objc func resourceChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if resource.typeCode == "sÿst" {
            self.read(system: resource)
            galaxyView.needsDisplay = true
        } else if resource.typeCode == "nebü" {
            self.read(nebula: resource)
            galaxyView.needsDisplay = true
        }
    }

    private func read(system: Resource) {
        let reader = BinaryDataReader(system.data)
        do {
            let point = NSPoint(
                x: CGFloat(try reader.read() as Int16),
                y: CGFloat(try reader.read() as Int16)
            )
            systems[system.id] = (system.name, point, [])
            for _ in 0..<16 {
                let id = Int(try reader.read() as Int16)
                systems[system.id]?.links.append(id)
            }
        } catch {}
    }

    private func read(nebula: Resource) {
        let reader = BinaryDataReader(nebula.data)
        do {
            let rect = NSRect(
                x: CGFloat(try reader.read() as Int16),
                y: CGFloat(try reader.read() as Int16),
                width: CGFloat(try reader.read() as Int16),
                height: CGFloat(try reader.read() as Int16)
            )
            nebulae[nebula.id] = (nebula.name, rect)
        } catch {}
    }

    func show(targetID: Int, manager: RFEditorManager) {
        window?.makeKeyAndOrderFront(self)
        self.targetID = targetID
        systems = [:]
        nebulae = [:]
        nebImages = [:]

        let systs = manager.allResources(ofType: ResourceType("sÿst"), currentDocumentOnly: false)
        for system in systs {
            guard systems[system.id] == nil else {
                continue
            }
            self.read(system: system)
        }

        let nebus = manager.allResources(ofType: ResourceType("nëbu"), currentDocumentOnly: false)
        for nebula in nebus {
            guard nebulae[nebula.id] == nil else {
                continue
            }
            self.read(nebula: nebula)
            // Find the largest available image
            let first = (nebula.id - 128) * 7 + 9500
            for id in (first..<first+7).reversed() {
                if let pict = manager.findResource(type: ResourceType("PICT"), id: id, currentDocumentOnly: false) {
                    pict.preview {
                        self.nebImages[nebula.id] = $0
                        self.galaxyView.needsDisplay = true
                    }
                }
            }
        }

        var point = galaxyView.transform.transform(systems[targetID]?.pos ?? .zero)
        point.x -= clipView.frame.midX
        point.y = galaxyView.frame.height - point.y - clipView.frame.midY
        galaxyView.scroll(point)
        galaxyView.needsDisplay = true
    }
}
