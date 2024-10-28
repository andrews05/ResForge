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
    private var stellarList: [Resource?] = Array(repeating: nil, count: 16)
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
        "System Map"
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
        for stellar in stellarList {
            if stellar != nil && stellarViews[stellar!.id] == nil {
                self.read(stellar: stellar!)
            }
        }

        self.updateStellarList()
    }

    private func updateStellarList() {
        // Reverse list so first draws on top
        systemView.subviews = Array(stellarViews.values).reversed()

        stellarTable.reloadData()
    }
    
    private func read() throws {
        let reader = BinaryDataReader(resource.data)
        for _ in 0..<18 {
            _ = try reader.read() as Int16
        }
        stellarList = try (0..<16).map { _ in
            Int(try reader.read() as Int16)
        }.map { stellarId in
            if 128...2175 ~= stellarId {
                manager.findResource(type: ResourceType("spöb"), id: stellarId, currentDocumentOnly: false)
            } else {
                nil
            }
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
        let destinationNavDefault = navDefault ?? stellarList.firstIndex(of: nil) ?? -1
        // Make sure there's room for another stellar in the system, and don't allow overwriting an existing navDefault
        if !(0...15 ~= destinationNavDefault) || stellarList[destinationNavDefault] != nil {
            return
        }
        manager.createResource(type: ResourceType("spöb"), id: nil) { [weak self] stellar in
            guard let self else { return }

            // Construct the minimum data required
            let writer = BinaryDataWriter()
            writer.write(Int16(position.x.rounded()))
            writer.write(Int16(position.y.rounded()))
            for _ in 0..<16 {
                writer.write(Int16(-1))
            }
            // Allow the DataChanged notification to create the view
            stellar.data = writer.data
            // Add the stellar to our navdefaults
            stellarList[destinationNavDefault] = stellar

            // Save the nav defaults
            let systWriter = BinaryDataWriter()
            // Make sure there's enough data in the resource to save nav defaults; otherwise initialize default data up to the end of the NavDefaults list
            if resource.data.count < 2 * 2 {
                systWriter.write(Int16(0)) // xPos/yPos = 0
                systWriter.write(Int16(0))
            }
            if resource.data.count < (2 + 16 + 16) * 2 {
                for _ in resource.data.count..<32 {
                    systWriter.write(Int16(-1)) // no hyperlinks or navdefaults
                }
            } else {
                systWriter.data = resource.data
            }
            for (i, navDefault) in stellarList.enumerated() {
                systWriter.write(Int16(navDefault?.id ?? -1), at: (2 + 16 + i) * 2)
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
        if resource.typeCode == "sÿst" || resource.typeCode == "spöb" {
            stellarViews[resource.id]?.updateFrame()
            if let i = self.row(for: resource) {
                stellarTable.reloadData(forRowIndexes: [i], columnIndexes: [1])
            }
            systemView.needsDisplay = true
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
        stellarList.count + 1
    }

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        row == 0
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        row != 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("HeaderCell")
        let view = tableView.makeView(withIdentifier: identifier, owner: self) as! NSTableCellView
        if let tableColumn {
            if let stellar = stellarList[row - 1] {
                switch tableColumn.identifier.rawValue {
                case "index":
                    view.textField?.stringValue = "#\(row)"
                case "id":
                    view.textField?.stringValue = "\(stellar.id)"
                case "name":
                    view.textField?.stringValue = stellar.name
                default:
                    break
                }
            } else {
                switch tableColumn.identifier.rawValue {
                case "index":
                    view.textField?.stringValue = "#\(row)"
                case "id":
                    view.textField?.stringValue = "-1"
                case "name":
                    view.textField?.stringValue = "(unused)"
                default:
                    break
                }
            }
        } else {
            view.textField?.stringValue = resource.name
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
        if stellarTable.selectedRow > 0 && stellarTable.selectedRowIndexes.count < stellarList.count {
            if let stellar = stellarList[stellarTable.selectedRow - 1], let view = stellarViews[stellar.id] {
                view.scrollToVisible(view.bounds.insetBy(dx: -4, dy: -4))
            }
        }
    }

    func syncSelectionToView() {
        for (i, stellar) in stellarList.enumerated() {
            if stellar != nil {
                stellarViews[stellar!.id]?.isHighlighted = stellarTable.isRowSelected(i + 1)
            }
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
        for navDefault in stellarTable.selectedRowIndexes {
            if let stellar = stellarList[navDefault - 1] {
                manager.open(resource: stellar) // Open the window to edit an existing selection
            } else {
                createStellar(navDefault: navDefault - 1) // Create a new stellar at the origin in the selected navDefault slot
            }
        }
    }

    func row(for resource: Resource) -> Int? {
        if let i = stellarList.firstIndex(of: resource) {
            return i + 1
        }
        return nil
    }

    var selectedStellars: [Resource] {
        get {
            stellarTable.selectedRowIndexes.compactMap { stellarList[$0 - 1] }
        }
        set {
            let indexes = IndexSet(newValue.compactMap(self.row(for:)))
            stellarTable.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }
}
