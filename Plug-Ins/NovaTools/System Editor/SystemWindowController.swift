import AppKit
import RFSupport
import OrderedCollections

struct NavDefault {
    let id: Int // If the stellar wasn't found we still need to retain the id
    let stellar: Resource?
    var view: StellarView?

    init(id: Int = -1, stellar: Resource? = nil) {
        self.id = id
        self.stellar = stellar
    }

    mutating func read(manager: RFEditorManager) {
        if let view {
            try? view.read()
        } else if let stellar {
            view = StellarView(stellar, manager: manager, isEnabled: stellar.document == manager.document)
        }
    }
}

extension NSPasteboard.PasteboardType {
    static let RFNavDefault = Self("com.resforge.nav-default")
}

class SystemWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["sÿsm"]
    let resource: Resource
    let manager: RFEditorManager

    @IBOutlet var stellarTable: NSTableView!
    @IBOutlet var systemView: SystemMapView!
    private(set) var navDefaults: [NavDefault] = []
    private var isSaving = false
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
        "System Map \(resource.id) - \(resource.name)"
    }

    override func windowDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(resourceListChanged(_:)), name: .DocumentDidAddResources, object: manager.document)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceListChanged(_:)), name: .DocumentDidRemoveResources, object: manager.document)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceIDChanged(_:)), name: .ResourceIDDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceNameChanged(_:)), name: .ResourceNameDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDataChanged(_:)), name: .ResourceDataDidChange, object: nil)

        // Allow re-arranging the stellars
        stellarTable.registerForDraggedTypes([.RFNavDefault])

        // Scroll to system center
        if var documentRect = systemView.enclosingScrollView?.documentVisibleRect {
            documentRect.origin.y *= -1 // Workaround an issue where the clip view is initially misplaced
            systemView.scroll(NSPoint(x: systemView.frame.midX - documentRect.midX, y: systemView.frame.midY - documentRect.midY))
        }

        self.reload()
    }

    private func reload() {
        navDefaults = Array(repeating: NavDefault(), count: 16)
        try? self.read()
        self.updateStellarList()
        window?.undoManager?.removeAllActions()
    }

    private func updateStellarList() {
        systemView.syncViews()
        stellarTable.reloadData()
    }
    
    private func read() throws {
        let reader = BinaryDataReader(resource.data)
        try reader.advance(18 * 2)
        for i in navDefaults.indices {
            let id = Int(try reader.read() as Int16)
            if 128...2175 ~= id {
                let stellar = manager.findResource(type: ResourceType("spöb"), id: id, currentDocumentOnly: false)
                navDefaults[i] = NavDefault(id: id, stellar: stellar)
                navDefaults[i].read(manager: manager)
            }
        }
    }

    private func setNavDefaults(_ newNavs: [NavDefault], actionName: String? = nil) {
        assert(newNavs.count == 16)
        let curNavs = navDefaults
        navDefaults = newNavs
        self.save()
        if let actionName {
            window?.undoManager?.setActionName(actionName)
        }
        window?.undoManager?.registerUndo(withTarget: self) { $0.setNavDefaults(curNavs) }
        self.syncSelectionFromView()
    }

    private func save() {
        let systWriter = BinaryDataWriter()
        // Make sure there's enough data in the resource to save nav defaults; otherwise initialize default data up to the end of the NavDefaults list
        if resource.data.count < (2 + 16 + 16) * 2 {
            systWriter.write(Int16(0))
            systWriter.write(Int16(0))
            for _ in 0..<32 {
                systWriter.write(Int16(-1))
            }
        } else {
            systWriter.data = resource.data
        }

        // Write the nav defaults
        for (i, nav) in navDefaults.enumerated() {
            systWriter.write(Int16(nav.id), at: (2 + 16 + i) * 2)
        }
        isSaving = true
        resource.data = systWriter.data
        isSaving = false
        self.updateStellarList()
    }

    @IBAction func zoomIn(_ sender: Any) {
        systemView.zoomIn(sender)
    }

    @IBAction func zoomOut(_ sender: Any) {
        systemView.zoomOut(sender)
    }

    @IBAction func delete(_ sender: Any) {
        var navDefaults = navDefaults
        let removed = stellarTable.selectedRowIndexes.count {
            let nav = navDefaults[$0 - 1]
            navDefaults[$0 - 1] = NavDefault()
            return nav.id != -1
        }
        if removed > 0 {
            let term = removed == 1 ? "Nav Default" : "Nav Defaults"
            self.setNavDefaults(navDefaults, actionName: "Remove \(term)")
        }
    }

    func createStellar(position: NSPoint = .zero, navIndex: Int? = nil) {
        guard let navIndex = navIndex ?? navDefaults.firstIndex(where: { $0.id == -1 }) else {
            return
        }
        manager.createResource(type: ResourceType("spöb"), id: nil) { [weak self] stellar in
            guard let self else { return }

            // Construct the minimum data required
            let writer = BinaryDataWriter()
            writer.write(Int16(position.x.rounded()))
            writer.write(Int16(position.y.rounded()))
            writer.write(Int16(0)) // graphic
            stellar.data = writer.data

            // Add the stellar to our nav defaults
            var navDefaults = navDefaults
            navDefaults[navIndex] = NavDefault(id: stellar.id, stellar: stellar)
            navDefaults[navIndex].read(manager: manager)
            self.setNavDefaults(navDefaults, actionName: "Add Nav Default")
            stellarTable.selectRowIndexes([navIndex + 1], byExtendingSelection: false)
        }
    }

    // MARK: - Notifications

    @objc func resourceListChanged(_ notification: Notification) {
        guard let resources = notification.userInfo?["resources"] as? [Resource] else {
            return
        }
        for resource in resources where resource.typeCode == "spöb" {
            if navDefaults.contains(where: { $0.id == resource.id }) {
                self.reload()
                break
            }
        }
    }

    @objc func resourceIDChanged(_ notification: Notification) {
        guard let resource = notification.object as? Resource else {
            return
        }
        if resource.typeCode == "spöb", navDefaults.contains(where: { $0.id == resource.id || $0.stellar == resource}) {
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
        guard !isSaving, !systemView.isSavingStellar, let resource = notification.object as? Resource else {
            return
        }
        if resource == self.resource {
            self.reload()
        } else if resource.typeCode == "spöb", let i = navDefaults.firstIndex(where: { $0.stellar == resource }) {
            navDefaults[i].read(manager: manager)
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
            let nav = navDefaults[row - 1]
            if let stellar = nav.stellar {
                // Dim id and name of foreign stellars
                let color: NSColor = stellar.document == resource.document ? .labelColor : .secondaryLabelColor
                switch tableColumn.identifier.rawValue {
                case "index":
                    view.textField?.stringValue = "\(row))"
                case "id":
                    view.textField?.stringValue = "\(nav.id)"
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
                    view.textField?.stringValue = "\(nav.id)"
                case "name":
                    view.textField?.stringValue = ""
                    view.textField?.placeholderString = nav.id == -1 ? "unused" : "not found"
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
            let nav = navDefaults[stellarTable.selectedRow - 1]
            if let view = nav.view {
                view.scrollToVisible(view.bounds.insetBy(dx: -4, dy: -4))
            }
        }
    }

    func syncSelectionToView() {
        for (i, nav) in navDefaults.enumerated() {
            nav.view?.isHighlighted = stellarTable.isRowSelected(i + 1)
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
            self.createStellar(navIndex: i)
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

    // MARK: - Drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        // Allow dragging any populated nav default
        guard navDefaults[row - 1].id != -1 else {
            return nil
        }
        let item = NSPasteboardItem()
        item.setString("\(row)", forType: .RFNavDefault)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        // Only allow a single item as a swap
        let count = info.draggingPasteboard.readObjects(forClasses: [NSPasteboardItem.self])?.count
        if count == 1 && dropOperation == .on && (info.draggingSource as? NSView) == tableView {
            return .move
        }
        return []
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let item = (info.draggingPasteboard.readObjects(forClasses: [NSPasteboardItem.self]) as? [NSPasteboardItem])?.first,
              let str = item.string(forType: .RFNavDefault),
              let oldRow = Int(str)
        else {
            return false
        }

        // Swap the two nav defaults
        var navDefaults = navDefaults
        navDefaults.swapAt(oldRow - 1, row - 1)
        self.setNavDefaults(navDefaults, actionName: "Move Nav Default")
        stellarTable.selectRowIndexes([row], byExtendingSelection: false)

        return true
    }
}
