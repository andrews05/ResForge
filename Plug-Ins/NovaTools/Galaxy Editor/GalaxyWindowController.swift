import AppKit
import RFSupport

class GalaxyWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["glxÿ"]
    let resource: Resource
    private let manager: RFEditorManager

    @IBOutlet var systemsList: NSOutlineView!
    @IBOutlet var clipView: NSClipView!
    @IBOutlet var galaxyView: GalaxyView!
    private(set) var systems: [Int: (resource: Resource, pos: NSPoint, links: [Int])] = [:]
    private(set) var nebulae: [Int: (name: String, area: NSRect)] = [:]
    private(set) var nebImages: [Int: NSImage] = [:]
    private var systemListItems: [Any] = []

    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func saveResource(_ sender: Any) {}
    func revertResource(_ sender: Any) {}
}

extension GalaxyWindowController {
    override var windowNibName: String {
        "GalaxyWindow"
    }
    var windowTitle: String {
        "Galaxy Map"
    }

    override func windowDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(resourceChanged(_:)), name: .DocumentDidAddResource, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceChanged(_:)), name: .DocumentDidRemoveResource, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceChanged(_:)), name: .ResourceIDDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceNameChanged(_:)), name: .ResourceNameDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDataChanged(_:)), name: .ResourceDataDidChange, object: nil)

        // Workaround a bug in interface builder that prevents setting the column width correctly
        systemsList.tableColumns[1].width = systemsList.frame.width - 2 - systemsList.tableColumns[0].width - systemsList.intercellSpacing.width

        let point = NSPoint(x: galaxyView.frame.midX - clipView.frame.midX, y: galaxyView.frame.midY - clipView.frame.midY)
        galaxyView.scroll(point)
        self.reload()
    }

    private func reload() {
        systems = [:]
        nebulae = [:]
        nebImages = [:]
        systemListItems = []

        let systs = manager.allResources(ofType: ResourceType("sÿst"), currentDocumentOnly: false)
        var currentDocument: NSDocument?
        for system in systs {
            guard systems[system.id] == nil else {
                continue
            }
            self.read(system: system)
            // Include a "group" row for each document
            if system.document != currentDocument {
                systemListItems.append(system.document?.displayName ?? "Other")
                currentDocument = system.document
            }
            systemListItems.append(system)
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

        galaxyView.needsDisplay = true
        systemsList.reloadData()
    }

    @IBAction func zoomIn(_ sender: Any) {
        galaxyView.zoomIn(sender)
    }

    @IBAction func zoomOut(_ sender: Any) {
        galaxyView.zoomOut(sender)
    }

    @objc func resourceChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource ?? notification.userInfo?["resource"] as? Resource else {
            return
        }
        if resource.typeCode == "sÿst" || resource.typeCode == "nebü" {
            self.reload()
        }
    }

    @objc func resourceNameChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if resource.typeCode == "sÿst" {
            galaxyView.needsDisplay = true
            systemsList.reloadData()
        } else if resource.typeCode == "nebü" {
            galaxyView.needsDisplay = true
        }
    }

    @objc func resourceDataChanged(_ notification: Notification) {
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
            let links = try (0..<16).map { _ in
                Int(try reader.read() as Int16)
            }
            systems[system.id] = (system, point, links)
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
}

extension GalaxyWindowController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        systemListItems.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        systemListItems[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        item is String
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let system = item as? Resource else {
            let view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderCell"), owner: self) as! NSTableCellView
            view.textField?.stringValue = item as! String
            return view
        }
        let view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
        switch tableColumn?.identifier.rawValue {
        case "id":
            view.textField?.stringValue = "\(system.id)"
        case "name":
            view.textField?.stringValue = system.name
        default:
            return nil
        }
        return view
    }

    @IBAction func doubleClickSystem(_ sender: Any) {
        if let system = systemListItems[systemsList.selectedRow] as? Resource {
            manager.open(resource: system)
        }
    }
}
