import Cocoa
import RFSupport

class GalaxyWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["sÿst"]
    
    @IBOutlet var clipView: NSClipView!
    @IBOutlet var galaxyView: GalaxyView!
    let resource: Resource
    let manager: RFEditorManager
    var systems: [Int: Resource] = [:]
    var points: [Int: NSPoint] = [:]
    var links: [(Int, Int)] = []
    
    override var windowNibName: String {
        return "GalaxyWindow"
    }

    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        systems = manager.allResources(ofType: resource.type, currentDocumentOnly: true).reduce(into: systems) { (result, resource) in
            if result[resource.id] == nil {
                result[resource.id] = resource
            }
        }
        for system in systems.values {
            let reader = BinaryDataReader(system.data)
            do {
                let x: Int16 = try reader.read()
                let y: Int16 = try reader.read()
                points[system.id] = NSPoint(x: Int(x), y: Int(y))
                for _ in 0..<16 {
                    let id = Int(try reader.read() as Int16)
                    links.append((system.id, id))
                }
            } catch {}
        }
        var linkMap: [NSPoint: [NSPoint]] = [:]
        super.init(window: nil)
        // Filter out invalid or duplicate links
        links = links.filter {
            guard var from = points[$0.0], var to = points[$0.1] else {
                return false
            }
            if from > to {
                swap(&from, &to)
            }
            if linkMap[from]?.contains(to) == true {
                return false
            }
            linkMap[from, default: []].append(to)
            return true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        // Center the view
        galaxyView.scroll(NSPoint(x: galaxyView.frame.midX-clipView.frame.midX, y: galaxyView.frame.midY-clipView.frame.midY))
    }

    @IBAction func saveResource(_ sender: Any) {
        self.setDocumentEdited(false)
    }

    @IBAction func revertResource(_ sender: Any) {
        self.setDocumentEdited(false)
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
