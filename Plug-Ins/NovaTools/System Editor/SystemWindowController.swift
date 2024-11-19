import AppKit
import RFSupport
import OrderedCollections

class SystemWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["sÿsm"]
    let resource: Resource
    let manager: RFEditorManager

    @IBOutlet var stellarTable: NSTableView!
    @IBOutlet var systemView: SystemMapView!
    private(set) var stellarViews: OrderedDictionary<Int, StellarView> = [:]
    private var navDefaults: [(id: Int, stellar: Resource?)] = Array(repeating: (-1, nil), count: 16)
    private var isSelectingStellars = false

    required init(resource: Resource, manager: RFEditorManager) {
        self.manager = manager
        self.resource = manager.findResource(type: ResourceType("sÿst"), id: resource.id, currentDocumentOnly: true)!
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func saveResource(_ sender: Any) {}
    func revertResource(_ sender: Any) {}
}

extension SystemWindowController {
    override var windowNibName: String {
        "SystemWindow"
    }
    var windowTitle: String {
        "System Map: \(resource.name) (ID \(resource.id))"
    }

    override func windowDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(resourceListChanged(_:)), name: .DocumentDidAddResources, object: manager.document)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceListChanged(_:)), name: .DocumentDidRemoveResources, object: manager.document)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceIDChanged(_:)), name: .ResourceIDDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceNameChanged(_:)), name: .ResourceNameDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDataChanged(_:)), name: .ResourceDataDidChange, object: nil)

        // Scroll to system center
        if var documentRect = systemView.enclosingScrollView?.documentVisibleRect {
            documentRect.origin.y *= -1 // Workaround an issue where the clip view is initially misplaced
            systemView.scroll(NSPoint(x: systemView.frame.midX - documentRect.midX, y: systemView.frame.midY - documentRect.midY))
        }

        self.reload()
    }

    private func reload() {
        try? read()

        stellarViews = [:]
        for (id, stellar) in navDefaults {
            if let stellar, stellarViews[id] == nil {
                self.read(stellar: stellar)
            }
        }

        self.updateStellarList()
    }

    private func updateStellarList() {
        systemView.syncViews()
        stellarTable.reloadData()
    }
    
    private func read() throws {
        let reader = BinaryDataReader(resource.data)
        try reader.advance(18 * 2)
        navDefaults = try (0..<16).map { _ in
            let id = Int(try reader.read() as Int16)
            if 128...2175 ~= id {
                let stellar = manager.findResource(type: ResourceType("spöb"), id: id, currentDocumentOnly: false)
                // If the stellar wasn't found we still need to retain the id
                return (id, stellar)
            }
            return (-1, nil)
        }
     }

    private func read(stellar: Resource) {
        if let view = stellarViews[stellar.id], view.resource == stellar {
            try? view.read()
        } else if let view = StellarView(stellar, manager: manager, isEnabled: stellar.document == manager.document) {
            stellarViews[stellar.id] = view
        }
    }

    @IBAction func zoomIn(_ sender: Any) {
        systemView.zoomIn(sender)
    }

    @IBAction func zoomOut(_ sender: Any) {
        systemView.zoomOut(sender)
    }

    @IBAction func copy(_ sender: Any) {
        let pb = NSPasteboard(name: .general)
        pb.declareTypes([.RFResource], owner: nil)
        pb.writeObjects(selectedStellars)
    }

    @IBAction func paste(_ sender: Any) {
        // Forward to the document
        manager.document?.perform(#selector(paste(_:)), with: sender)
    }

    func createStellar(position: NSPoint = .zero, navDefault: Int? = nil) {
        guard let navDefault = navDefault ?? navDefaults.firstIndex(where: { $0.id == -1 }) else {
            return
        }
        manager.createResource(type: ResourceType("spöb"), id: nil) { [weak self] stellar in
            guard let self else { return }

            // Construct the minimum data required
            let writer = BinaryDataWriter()
            writer.write(Int16(position.x.rounded()))
            writer.write(Int16(position.y.rounded()))
            writer.write(Int16(0)) // graphic
            // Allow the DataChanged notification to create the view
            stellar.data = writer.data
            // Add the stellar to our navdefaults
            navDefaults[navDefault] = (stellar.id, stellar)

            // Save the nav defaults
            let systWriter = BinaryDataWriter()
            // Make sure there's enough data in the resource to save nav defaults; otherwise initialize default data up to the end of the NavDefaults list
            if resource.data.count < (2 + 16 + 16) * 2 {
                if resource.data.count < 2 * 2 {
                    // Completely empty resource; write default x/yPos here
                    systWriter.write(Int16(0))
                    systWriter.write(Int16(0))
                }

                // Resource now has some data but not the full amount, intitalize the minimum we need to write nav defaults
                for _ in resource.data.count..<32 {
                    systWriter.write(Int16(-1)) // no hyperlinks or navdefaults
                }
            } else {
                systWriter.data = resource.data
            }
            for (i, navDefault) in navDefaults.enumerated() {
                systWriter.write(Int16(navDefault.id), at: (2 + 16 + i) * 2)
            }
            resource.data = systWriter.data

            // Update the view to reflect the new stellar
            if let view = stellarViews[stellar.id] {
                view.isHighlighted = true
                self.syncSelectionFromView(clicked: view)
            }
        }
    }

    // MARK: - Notifications

    @objc func resourceListChanged(_ notification: Notification) {
        guard let resources = notification.userInfo?["resources"] as? [Resource] else {
            return
        }
        let shouldReload = resources.contains {
            !$0.data.isEmpty && ["sÿst", "spöb", "spïn", "rlëD", "PICT"].contains($0.typeCode)
        }
        if shouldReload {
            self.reload()
            if notification.name == .DocumentDidAddResources {
                // Select added stellars
                selectedStellars = resources.filter { $0.typeCode == "spöb" }
                if stellarTable.selectedRow > 0 {
                    stellarTable.scrollRowToVisible(stellarTable.selectedRow)
                }
            }
        }
    }

    @objc func resourceIDChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if ["sÿst", "spöb", "spïn", "rlëD", "PICT"].contains(resource.typeCode) {
            self.reload()
        }
    }

    @objc func resourceNameChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if resource.typeCode == "spöb", let i = self.row(for: resource) {
            stellarTable.reloadData(forRowIndexes: [i], columnIndexes: [2])
        }
    }

    @objc func resourceDataChanged(_ notification: Notification) {
        guard !systemView.isSavingStellar, let resource = notification.object as? Resource else {
            return
        }
        if resource.typeCode == "spöb" {
            self.read(stellar: resource)
            self.updateStellarList()
            self.syncSelectionFromView()
            systemView.needsDisplay = true
        } else if resource.typeCode == "sÿst" {
            self.reload()
            self.syncSelectionFromView()
            systemView.needsDisplay = true
        } else if ["spïn", "rlëD", "PICT"].contains(resource.typeCode) {
            self.syncSelectionFromView()
            systemView.needsDisplay = true
        }
    }
}

extension SystemWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        navDefaults.count + 1
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        row == 0
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if row > 0, let stellar = navDefaults[row - 1].stellar {
            // Prevent selection of foreign stellars
            return stellar.document == resource.document
        }
        return row != 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("HeaderCell")
        let view = tableView.makeView(withIdentifier: identifier, owner: self) as! NSTableCellView
        if let tableColumn {
            let (id, stellar) = navDefaults[row - 1]
            if let stellar {
                // Dim id and name of foreign stellars
                let color: NSColor = stellar.document == resource.document ? .labelColor : .secondaryLabelColor
                switch tableColumn.identifier.rawValue {
                case "index":
                    view.textField?.stringValue = "\(row))"
                case "id":
                    view.textField?.stringValue = "\(id)"
                    view.textField?.textColor = color
                case "name":
                    view.textField?.stringValue = stellar.name
                    view.textField?.textColor = color
                default:
                    break
                }
            } else {
                switch tableColumn.identifier.rawValue {
                case "index":
                    view.textField?.stringValue = "\(row))"
                case "id":
                    view.textField?.stringValue = "\(id)"
                case "name":
                    view.textField?.stringValue = ""
                    view.textField?.placeholderString = id == -1 ? "unused" : "not found"
                default:
                    break
                }
            }
        } else {
            view.textField?.stringValue = "Nav Defaults"
        }
        return view
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingStellars else {
            return
        }
        self.syncSelectionToView()
        systemView.restackStellars()

        // Scroll to last selected stellar, unless selected all
        if stellarTable.selectedRow > 0 && stellarTable.selectedRowIndexes.count < navDefaults.count {
            let navDefault = navDefaults[stellarTable.selectedRow - 1]
            if let view = stellarViews[navDefault.id] {
                view.scrollToVisible(view.bounds.insetBy(dx: -4, dy: -4))
            }
        }
    }

    func syncSelectionToView() {
        for (i, navDefault) in navDefaults.enumerated() {
            stellarViews[navDefault.id]?.isHighlighted = stellarTable.isRowSelected(i + 1)
        }
    }

    func syncSelectionFromView(clicked: StellarView? = nil) {
        isSelectingStellars = true
        selectedStellars = systemView.selectedStellars.map(\.resource)
        isSelectingStellars = false
        if let clicked, let i = self.row(for: clicked.resource) {
            stellarTable.scrollRowToVisible(i)
        }
    }

    @IBAction func doubleClickStellar(_ sender: Any) {
        guard stellarTable.clickedRow != 0 else {
            return
        }
        let i = stellarTable.clickedRow - 1
        if stellarTable.selectedRowIndexes.count == 1 && navDefaults[i].id == -1 {
            // Create a new stellar at the origin in the selected navDefault slot
            self.createStellar(navDefault: i)
        } else {
            // Open the selected stellars
            for stellar in selectedStellars {
                manager.open(resource: stellar)
            }
        }
    }

    func row(for resource: Resource) -> Int? {
        if let i = navDefaults.firstIndex(where: { $0.stellar == resource }) {
            return i + 1
        }
        return nil
    }

    var selectedStellars: [Resource] {
        get {
            stellarTable.selectedRowIndexes.compactMap { navDefaults[$0 - 1].stellar }
        }
        set {
            let indexes = IndexSet(newValue.compactMap(self.row(for:)))
            stellarTable.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }
}
