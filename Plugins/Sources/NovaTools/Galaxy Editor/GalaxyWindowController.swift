import AppKit
import RFSupport
import OrderedCollections

class GalaxyWindowController: AbstractEditor, ResourceEditor {
    static var bundle: Bundle { .module }
    static let supportedTypes = ["glxÿ"]
    let resource: Resource
    let manager: RFEditorManager

    @IBOutlet var resourceTable: NSTableView!
    @IBOutlet var galaxyView: GalaxyView!
    @IBOutlet var backgroundView: BackgroundView!
    private(set) var systemViews: OrderedDictionary<Int, SystemView> = [:]
    private(set) var nebulaViews: OrderedDictionary<Int, NebulaView> = [:]
    private var systemList: [Resource] = []
    private var nebulaList: [Resource] = []
    private var isSelectingResources = false

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
    override var windowNibName: NSNib.Name {
        "GalaxyWindow"
    }
    var windowTitle: String {
        "Galaxy Map"
    }

    override func windowDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(resourceListChanged(_:)), name: .DocumentDidAddResources, object: manager.document)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceListChanged(_:)), name: .DocumentDidRemoveResources, object: manager.document)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceIDChanged(_:)), name: .ResourceIDDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceNameChanged(_:)), name: .ResourceNameDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDataChanged(_:)), name: .ResourceDataDidChange, object: nil)

        self.reload()
    }

    private func reload() {
        systemViews = [:]
        nebulaViews = [:]

        let systs = manager.allResources(ofType: .system, currentDocumentOnly: false)
        for system in systs {
            if systemViews[system.id] == nil {
                self.read(system: system)
            }
        }

        let nebus = manager.allResources(ofType: .nebula, currentDocumentOnly: false)
        for nebula in nebus {
            if nebulaViews[nebula.id] == nil {
                self.read(nebula: nebula)
            }
        }

        self.updateResourceLists()
    }

    private func updateResourceLists() {
        // Reverse list so first draws on top
        galaxyView.subviews = Array(systemViews.values).reversed()
        backgroundView.subviews = Array(nebulaViews.values)
        // Don't include foreign resources in the list
        systemList = manager.allResources(ofType: .system, currentDocumentOnly: true)
        nebulaList = manager.allResources(ofType: .nebula, currentDocumentOnly: true)
        resourceTable.reloadData()
    }

    private func read(system: Resource) {
        if let view = systemViews[system.id], view.resource == system {
            try? view.read()
        } else if let view = SystemView(system, manager: manager) {
            systemViews[system.id] = view
        }
    }

    private func read(nebula: Resource) {
        if let view = nebulaViews[nebula.id], view.resource == nebula {
            try? view.read()
        } else if let view = NebulaView(nebula, manager: manager) {
            nebulaViews[nebula.id] = view
        }
    }

    @IBAction func zoomIn(_ sender: Any) {
        galaxyView.zoomIn(sender)
    }

    @IBAction func zoomOut(_ sender: Any) {
        galaxyView.zoomOut(sender)
    }

    @IBAction func copy(_ sender: Any) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(selectedResources)
    }

    @IBAction func paste(_ sender: Any) {
        // Forward to the document
        manager.document?.perform(#selector(paste(_:)), with: sender)
    }

    func createSystem(position: NSPoint) {
        manager.createResource(type: .system, id: systemList.last?.id) { [weak self] system in
            guard let self else { return }

            // Construct the minimum data required
            let writer = BinaryDataWriter()
            writer.write(Int16(position.x.rounded()))
            writer.write(Int16(position.y.rounded()))
            for _ in 0..<32 {
                writer.write(Int16(-1))
            }
            // Allow the DataChanged notification to create the view
            system.data = writer.data
            if let i = self.row(for: system) {
                resourceTable.selectRowIndexes([i], byExtendingSelection: false)
                resourceTable.scrollRowToVisible(i)
            }
        }
    }

    // MARK: - Notifications

    @objc func resourceListChanged(_ notification: Notification) {
        guard let resources = notification.userInfo?["resources"] as? [Resource] else {
            return
        }
        let shouldReload = resources.contains {
            !$0.data.isEmpty && ($0.type == .system || $0.type == .nebula)
        }
        if shouldReload {
            self.reload()
            if notification.name == .DocumentDidAddResources {
                // Select added resources
                selectedResources = resources.filter { $0.type == .system || $0.type == .nebula }
                if resourceTable.selectedRow > 0 {
                    resourceTable.scrollRowToVisible(resourceTable.selectedRow)
                }
            }
        }
    }

    @objc func resourceIDChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if resource.type == .system || resource.type == .nebula {
            self.reload()
        }
    }

    @objc func resourceNameChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if resource.type == .system {
            systemViews[resource.id]?.updateFrame()
        } else if resource.type == .nebula {
            nebulaViews[resource.id]?.needsDisplay = true
        }
        if let i = self.row(for: resource) {
            resourceTable.reloadData(forRowIndexes: [i], columnIndexes: [1])
        }
    }

    @objc func resourceDataChanged(_ notification: Notification) {
        guard !galaxyView.isSavingItem, let resource = notification.object as? Resource else {
            return
        }
        if resource.type == .system {
            self.read(system: resource)
            self.updateResourceLists()
            self.syncSelectionFromView()
        } else if resource.type == .nebula {
            self.read(nebula: resource)
            self.updateResourceLists()
            self.syncSelectionFromView()
        }
    }
}

extension GalaxyWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        var rows = systemList.count + 1
        if !nebulaList.isEmpty {
            rows += nebulaList.count + 1
        }
        return rows
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        row == 0 || row == systemList.count + 1
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        row != 0 && row != systemList.count + 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("HeaderCell")
        let view = tableView.makeView(withIdentifier: identifier, owner: self) as! NSTableCellView
        if let tableColumn {
            let resource = self.resource(for: row)
            switch tableColumn.identifier.rawValue {
            case "id":
                view.textField?.stringValue = "\(resource.id)"
            case "name":
                view.textField?.stringValue = resource.name
            default:
                break
            }
        } else if row == 0 {
            view.textField?.stringValue = "Systems"
        } else {
            view.textField?.stringValue = "Nebulae"
        }
        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingResources else {
            return
        }
        let table = notification.object as! NSTableView
        self.syncSelectionToView()
        galaxyView.restackViews()

        // Scroll to last selected resource, unless selected all
        if table.selectedRow > 0 && table.selectedRowIndexes.count < systemList.count + nebulaList.count {
            let resource = self.resource(for: table.selectedRow)
            let view = resource.type == .system ? systemViews[resource.id] : nebulaViews[resource.id]
            if let view {
                view.scrollToVisible(view.bounds.insetBy(dx: -4, dy: -4))
            }
        }
    }

    func syncSelectionToView() {
        for (i, system) in systemList.enumerated() {
            systemViews[system.id]?.isHighlighted = resourceTable.isRowSelected(i + 1)
        }
        for (i, nebula) in nebulaList.enumerated() {
            nebulaViews[nebula.id]?.isHighlighted = resourceTable.isRowSelected(i + systemList.count + 2)
        }
    }

    func syncSelectionFromView(clicked: ItemView? = nil) {
        isSelectingResources = true
        selectedResources = galaxyView.selectedItems.map(\.resource)
        isSelectingResources = false
        if let clicked, let i = self.row(for: clicked.resource) {
            resourceTable.scrollRowToVisible(i)
        }
    }

    @IBAction func doubleClickResource(_ sender: Any) {
        guard !self.tableView(resourceTable, isGroupRow: resourceTable.clickedRow) else {
            return
        }
        for resource in selectedResources {
            manager.open(resource: resource)
        }
    }

    func row(for resource: Resource) -> Int? {
        if resource.type == .system, let i = systemList.firstIndex(of: resource) {
            return i + 1
        } else if resource.type == .nebula, let i = nebulaList.firstIndex(of: resource) {
            return i + systemList.count + 2
        }
        return nil
    }

    func resource(for row: Int) -> Resource {
        if row <= systemList.count {
            systemList[row - 1]
        } else {
            nebulaList[row - systemList.count - 2]
        }
    }

    var selectedResources: [Resource] {
        get {
            resourceTable.selectedRowIndexes.map(self.resource(for:))
        }
        set {
            let indexes = IndexSet(newValue.compactMap(self.row(for:)))
            resourceTable.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }
}
