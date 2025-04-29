import AppKit
import RFSupport
import TemplateEditor

extension Notification.Name {
    static let DocumentInfoDidChange        = Self("DocumentInfoDidChange")
    static let DocumentSelectionDidChange   = Self("DocumentSelectionDidChange")
}

extension NSToolbarItem.Identifier {
    static let addResource      = Self("addResource")
    static let deleteResource   = Self("deleteResource")
    static let editResource     = Self("editResource")
    static let editHex          = Self("editHex")
    static let exportResources  = Self("exportResources")
    static let showInfo         = Self("showInfo")
    static let searchField      = Self("searchField")
}

enum FileFork {
    case data
    case rsrc
    var name: String {
        switch self {
        case .data:
            return NSLocalizedString("Data Fork", comment: "")
        case .rsrc:
            return NSLocalizedString("Resource Fork", comment: "")
        }
    }
}

class ResourceDocument: NSDocument, NSWindowDelegate, NSDraggingDestination, NSToolbarDelegate {
    @IBOutlet var dataSource: ResourceDataSource!
    @IBOutlet var statusText: NSTextField!
    @IBOutlet var importPanel: ImportPanel!
    private var searchField: NSSearchField!
    private(set) lazy var directory = ResourceDirectory(self)
    private(set) lazy var editorManager = EditorManager(self)
    private(set) lazy var createController = CreateResourceController(self)
    private var fork: FileFork!
    private(set) var format: any ResourceFileFormat = ClassicFormat()
    private(set) var revision = 0 // Used to track new resources

    @objc dynamic var hfsType: OSType = 0 {
        didSet {
            if hfsType != oldValue {
                self.undoManager?.setActionName(NSLocalizedString("Change File Type", comment: ""))
                self.undoManager?.registerUndo(withTarget: self, handler: { $0.hfsType = oldValue })
            }
        }
    }
    @objc dynamic var hfsCreator: OSType = 0 {
        didSet {
            if hfsCreator != oldValue {
                self.undoManager?.setActionName(NSLocalizedString("Change File Creator", comment: ""))
                self.undoManager?.registerUndo(withTarget: self, handler: { $0.hfsCreator = oldValue })
            }
        }
    }

    override var windowNibName: NSNib.Name {
        "ResourceDocument"
    }

    static func all() -> [ResourceDocument] {
        return NSDocumentController.shared.documents.compactMap { $0 as? ResourceDocument }
    }

    // MARK: - File Management

    override func read(from url: URL, ofType typeName: String) throws {
        // Work out which fork to parse
        if fork == nil {
            // If we are opening the document for the first time, attempt to get fork from the open panel,
            // falling back to the resource fork if it exists, otherwise the data fork.
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
            let hasRsrc = (values.totalFileSize! - values.fileSize!) > 0
            fork = (NSDocumentController.shared as! OpenPanelDelegate).getSelectedFork() ?? (hasRsrc ? .rsrc : .data)
        }

        // Read file and determine format
        let data: Data
        if fork == .data {
            data = try Data(contentsOf: url)
            format = try ResourceFormat.from(data: data)
        } else {
            // Always use classic for resource fork
            format = ClassicFormat()
            do {
                data = try Data(contentsOf: url.appendingPathComponent("..namedfork/rsrc"))
            } catch CocoaError.fileReadNoSuchFile {
                // Resource fork does not exist but we can create it on save
                data = Data()
            }
        }

        // Read resources
        let resourceMap: ResourceMap
        do {
            resourceMap = data.isEmpty ? [:] : try format.read(data)
        } catch {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Get type and creator - make sure undo registration is disabled while configuring
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        self.undoManager?.disableUndoRegistration()
        _ = editorManager.closeAll(saving: false)
        hfsType = attrs[.hfsTypeCode] as! OSType
        hfsCreator = attrs[.hfsCreatorCode] as! OSType
        revision = 0
        directory.reset(resourceMap)
        dataSource?.reload()
        self.undoManager?.enableUndoRegistration()
    }

    override class var autosavesInPlace: Bool { false }

    override class var writableTypes: [String] { ResourceFormat.creatableTypes }

    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        true
    }

    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        if let ext = format.filenameExtension(for: fileURL) {
            savePanel.nameFieldStringValue.append(".\(ext)")
        }
        savePanel.isExtensionHidden = false
        savePanel.allowsOtherFileTypes = true
        return super.prepareSavePanel(savePanel)
    }

    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        if saveOperation == .saveOperation && fork == .rsrc, let fileURL {
            // In place save of resource fork. We want to preserve all other aspects of the file, such as the data fork and finder flags.
            // Relying on the default implementation can result in some oddities, so instead we'll just write out the resource fork directly.
            // Note this isn't strictly "safe". We also don't call `unblockUserInteraction()` here - it may be better to remain synchronous.

            let data = try format.write(directory.resourceMap)
            // Check if the file is being renamed for some reason and copy the existing file to the new location.
            let moved = fileURL != url
            if moved {
                try FileManager.default.copyItem(at: fileURL, to: url)
            }
            do {
                let writeUrl = url.appendingPathComponent("..namedfork/rsrc")
                try data.write(to: writeUrl)
                try FileManager.default.setAttributes([.hfsTypeCode: hfsType, .hfsCreatorCode: hfsCreator], ofItemAtPath: url.path)
            } catch let error {
                if moved {
                    try? FileManager.default.removeItem(at: url)
                }
                throw error
            }
        } else {
            try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
        }

        revision += 1
        for resource in directory.resourceMap.values.joined() {
            resource.resetState()
        }
        DispatchQueue.main.async { [self] in
            dataSource.reload(selecting: dataSource.selectedResources())
            // Update info window
            NotificationCenter.default.post(name: .DocumentInfoDidChange, object: self)
            self.updateStatus()
        }
    }

    override func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        // We're necessarily writing the data fork here
        if saveOperation != .saveAsOperation {
            try super.write(to: url, ofType: typeName)
        } else {
            // Set format from typeName and clear type/creator, but make
            // sure the original values are restored if an error occurs.
            self.undoManager?.disableUndoRegistration()
            defer {
                self.undoManager?.enableUndoRegistration()
            }
            let origFormat = format
            let origType = hfsType
            let origCreator = hfsCreator
            format = ResourceFormat.from(typeName: typeName)
            hfsType = 0
            hfsCreator = 0
            do {
                try super.write(to: url, ofType: typeName)
            } catch let error {
                format = origFormat
                hfsType = origType
                hfsCreator = origCreator
                throw error
            }
            fork = .data
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        return try format.write(directory.resourceMap)
    }

    override func fileAttributesToWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL absoluteOriginalContentsURL: URL?) throws -> [String: Any] {
        return [FileAttributeKey.hfsTypeCode.rawValue: hfsType, FileAttributeKey.hfsCreatorCode.rawValue: hfsCreator]
    }

    // MARK: - Export

    @IBAction func exportResource(_ sender: Any) {
        self.exportResources(raw: false)
    }

    @IBAction func exportRawResource(_ sender: Any) {
        self.exportResources(raw: true)
    }

    private func exportResources(raw: Bool) {
        let resources = dataSource.selectedResources(deep: true)
        if resources.count > 1 {
            // Multiple resources, choose a directory to export to
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.prompt = NSLocalizedString("Choose", comment: "")
            panel.message = NSLocalizedString("Choose where to export the selected resources", comment: "")
            panel.beginSheetModal(for: self.windowForSheet!) { modalResponse in
                if modalResponse == .OK, let saveDir = panel.url {
                    for resource in resources {
                        let exporter = raw ? nil : PluginRegistry.exportProviders[resource.typeCode]
                        let filename = resource.filenameForExport(using: exporter)
                        var url = saveDir.appendingPathComponent(filename.name).appendingPathExtension(filename.ext)
                        // Ensure unique name
                        var i = 2
                        while FileManager.default.fileExists(atPath: url.path) {
                            url = saveDir.appendingPathComponent("\(filename.name) \(i)").appendingPathExtension(filename.ext)
                            i += 1
                        }
                        self.export(resource: resource, to: url, using: exporter)
                    }
                }
            }
        } else if resources.count == 1 {
            // Single resource, show save panel
            let resource = resources.first!
            let exporter = raw ? nil : PluginRegistry.exportProviders[resource.typeCode]
            let panel = NSSavePanel()
            let filename = resource.filenameForExport(using: exporter)
            panel.nameFieldStringValue = "\(filename.name).\(filename.ext)"
            panel.isExtensionHidden = false
            if exporter != nil {
                panel.allowedFileTypes = [filename.ext]
            }
            panel.beginSheetModal(for: self.windowForSheet!) { modalResponse in
                if modalResponse == .OK, let url = panel.url {
                    self.export(resource: resource, to: url, using: exporter)
                }
            }
        }
    }

    private func export(resource: Resource, to url: URL, using exporter: ExportProvider.Type?) {
        do {
            if !resource.data.isEmpty, let exporter {
                try exporter.export(resource, to: url)
            } else {
                try resource.data.write(to: url)
            }
        } catch let error {
            self.presentError(error)
        }
    }

    // MARK: - Toolbar Management

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .toggleSidebar,
            .addResource,
            .deleteResource,
            .editResource,
            .editHex,
            .exportResources,
            .showInfo,
            .searchField,
            .space,
            .flexibleSpace
        ]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var defaults: [NSToolbarItem.Identifier] = [
            .toggleSidebar,
            .space,
            .addResource,
            .editResource,
            .exportResources,
            .showInfo,
            .flexibleSpace,
            .searchField
        ]
        if #available(macOS 11.0, *) {
            defaults.removeFirst(.space)
        }
        return defaults
    }

    // Get a system symbol if on 11.0 or later, otherwise a standard image
    private func symbolImage(named name: String, fallback: String? = nil) -> NSImage? {
        if #available(macOS 11.0, *) {
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        let image = NSImage(named: fallback ?? name)
        image?.isTemplate = true
        return image
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        // Create the toolbar items. On macOS 11 we use the special search toolbar item as well as the system symbol images.
        let item: NSToolbarItem
        if itemIdentifier == .searchField {
            if #available(macOS 11.0, *) {
                let searchItem = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
                searchItem.preferredWidthForSearchField = 180
                searchField = searchItem.searchField
                item = searchItem
            } else {
                item = NSToolbarItem(itemIdentifier: itemIdentifier)
                searchField = NSSearchField()
                item.view = searchField
                item.label = NSLocalizedString("Search", comment: "")
                item.paletteLabel = item.label
                item.minSize = NSSize(width: 120, height: 0)
                item.maxSize = NSSize(width: 180, height: 0)
            }
            item.action = #selector(ResourceDataSource.filter(_:))
            item.target = dataSource
            return item
        }

        item = NSToolbarItem(itemIdentifier: itemIdentifier)
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 36, height: 0))
        button.bezelStyle = .texturedRounded
        item.view = button
        item.target = self
        switch itemIdentifier {
        case .addResource:
            item.label = NSLocalizedString("Add", comment: "")
            item.image = NSImage(named: NSImage.addTemplateName)
            item.action = #selector(createNewItem(_:))
        case .deleteResource:
            item.label = NSLocalizedString("Delete", comment: "")
            item.image = self.symbolImage(named: "trash", fallback: "NSToolbarDelete")
            item.action = #selector(delete(_:))
            item.isEnabled = false
        case .editResource:
            item.label = NSLocalizedString("Edit", comment: "")
            item.image = self.symbolImage(named: "square.and.pencil")
            item.action = #selector(openResources(_:))
            item.isEnabled = false
        case .editHex:
            item.label = NSLocalizedString("Edit Hex", comment: "")
            item.image = self.symbolImage(named: "rectangle.and.pencil.and.ellipsis")
            item.action = #selector(openResourcesAsHex(_:))
            item.isEnabled = false
        case .exportResources:
            item.label = NSLocalizedString("Export", comment: "")
            item.image = NSImage(named: NSImage.shareTemplateName)
            item.action = #selector(exportResource(_:))
            item.isEnabled = false
        case .showInfo:
            item.label = NSLocalizedString("Show Info", comment: "")
            item.image = self.symbolImage(named: "info.circle", fallback: "NSToolbarGetInfo")
            item.target = NSApp.delegate
            item.action = #selector(ApplicationDelegate.showInfo(_:))
        default:
            break
        }
        item.paletteLabel = item.label
        return item
    }

    func toolbarWillAddItem(_ notification: Notification) {
        // Set the correct action for the sidebar toggle
        // This can't be done in itemForItemIdentifier as it will be overridden afterward
        if let item = notification.userInfo?["item"] as? NSToolbarItem, item.itemIdentifier == .toggleSidebar {
            item.action = #selector(toggleTypes(_:))
            (item.view as? NSControl)?.action = #selector(toggleTypes(_:))
        }
    }

    @objc func validateToolbarItems(_ notification: Notification) {
        updateStatus()
        if let toolbar = windowControllers.first?.window?.toolbar {
            let enabled = dataSource.selectionCount() > 0
            for item in toolbar.items {
                switch item.itemIdentifier {
                case .deleteResource, .editResource, .editHex, .exportResources:
                    item.isEnabled = enabled
                default:
                    break
                }
            }
        }
    }

    @IBAction func showFind(_ sender: Any) {
        self.windowForSheet?.makeFirstResponder(searchField)
    }

    // MARK: - Window Management

    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        windowController.window?.registerForDraggedTypes([.RFResource])
        self.updateStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(validateToolbarItems(_:)), name: .DocumentSelectionDidChange, object: self)
        if #available(macOS 11.0, *) {
            (statusText.superview?.superview as? NSBox)?.fillColor = .windowBackgroundColor
        }
    }

    func updateStatus() {
        guard let statusText else {
            return
        }
        let count = directory.count
        var status = count == 1 ? "\(count) resource" : "\(count) resources"
        if count > 0 {
            let selected = dataSource.selectedResources()
            if !selected.isEmpty || !directory.filter.isEmpty {
                let matching = directory.filteredCount(type: dataSource.currentType)
                if selected.isEmpty {
                    status += ", \(matching) matching filter"
                } else if !dataSource.useTypeList && directory.filter.isEmpty {
                    status += ", \(selected.count) selected"
                } else {
                    status += ", \(selected.count) of \(matching) selected"
                }
            }
        }
        if let fork {
            var formatName = format.name
            if fork == .rsrc {
                formatName += " (\(fork.name))"
            }
            status = "\(formatName) — \(status)"
        }
        statusText.stringValue = status
    }

    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Can't drag to self
        if (sender.draggingSource as? NSView)?.window?.delegate === self {
            return []
        }
        return .copy
    }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let resources = sender.draggingPasteboard.readObjects(forClasses: [Resource.self]) as? [Resource] {
            self.add(resources: resources)
            return true
        }
        return false
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        if editorManager.closeAll(saving: true) {
            super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
        }
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(cut(_:)),
            #selector(copy(_:)),
            #selector(delete(_:)),
            #selector(openResources(_:)),
            #selector(openResourcesInTemplate(_:)),
            #selector(openResourcesAsHex(_:)),
            #selector(exportResource(_:)):
            return dataSource.selectionCount() > 0
        case #selector(revertResource(_:)):
            menuItem.title = NSLocalizedString("Revert Resource Content", comment: "")
            return dataSource.selectedResources(deep: true).filter(\.isDataModified).count > 0
        case #selector(showFind(_:)):
            return windowForSheet?.toolbar?.isVisible == true
        case #selector(toggleTypes(_:)):
            menuItem.title = NSLocalizedString(dataSource.useTypeList ? "Hide Sidebar" : "Show Sidebar", comment: "")
            return true
        case #selector(switchView(_:)):
            switch menuItem.tag {
            case 1:
                menuItem.state = dataSource.resourcesView is StandardController ? .on : .off
                return dataSource.useTypeList
            case 2:
                menuItem.state = dataSource.resourcesView is CollectionController ? .on : .off
                if let type = dataSource.currentType {
                    return dataSource.useTypeList && PluginRegistry.previewProviders[type.code] != nil
                }
                return false
            case 3:
                menuItem.state = dataSource.resourcesView is BulkController ? .on : .off
                return editorManager.template(for: dataSource.currentType, basic: true) != nil
            default:
                return false
            }
        case #selector(exportCSV(_:)):
            if let type = dataSource.selectedType() {
                menuItem.title = NSLocalizedString("Export ‘\(type.code)’ to CSV…", comment: "")
                return editorManager.template(for: type, basic: true) != nil
            }
            menuItem.title = NSLocalizedString("Export to CSV…", comment: "")
            return false
        default:
            // Auto validation of save menu item isn't working for existing documents - force override
            if menuItem.identifier?.rawValue == "save" {
                return self.isDocumentEdited
            }
            return super.validateMenuItem(menuItem)
        }
    }

    // MARK: - Document Management

    @IBAction func createNewItem(_ sender: Any) {
        // Pass type and id of currently selected item
        if let resource = dataSource.selectedResources().first {
            createController.show(type: resource.type, id: resource.id)
        } else {
            createController.show(type: dataSource.selectedType())
        }
    }

    @IBAction func openResources(_ sender: Any) {
        // Use hex editor if holding option key
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            self.openResourcesAsHex(sender)
            return
        }
        for resource in dataSource.selectedResources() {
            editorManager.open(resource: resource)
        }
    }

    @IBAction func openResourcesInTemplate(_ sender: Any) {
        let resources = dataSource.selectedResources()
        guard let type = resources.first?.type else {
            return
        }
        SelectTemplateController().show(self, type: type) { template in
            for resource in resources {
                self.editorManager.open(resource: resource, using: TemplateEditor.self, template: template)
            }
        }
    }

    @IBAction func openResourcesAsHex(_ sender: Any) {
        for resource in dataSource.selectedResources() {
            editorManager.open(resource: resource, using: PluginRegistry.hexEditor)
        }
    }

    // INFO: This is *not* named toggleSidebar in order to avoid a responder conflict
    @IBAction func toggleTypes(_ sender: Any) {
        dataSource.toggleSidebar()
    }

    @IBAction func switchView(_ sender: NSMenuItem) {
        let view: ResourcesView
        switch sender.tag {
        case 1:
            view = dataSource.outlineController
        case 2:
            view = dataSource.collectionController
        case 3:
            view = dataSource.bulkController
        default:
            return
        }
        if view !== dataSource.resourcesView {
            dataSource.setView(view, retainSelection: true)
        }
    }

    @IBAction func exportCSV(_ sender: Any) {
        guard let type = dataSource.selectedType() else {
            return
        }
        do {
            try dataSource.bulkController.loadTemplate(type: type)
        } catch let error {
            self.presentError(error)
        }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv"]
        panel.nameFieldStringValue = "\(type.code).csv"
        panel.beginSheetModal(for: self.windowForSheet!) { modalResponse in
            if modalResponse == .OK, let url = panel.url {
                do {
                    try self.dataSource.bulkController.exportCSV(to: url)
                } catch let error {
                    self.presentError(error)
                }
            }
        }
    }

    @IBAction func importCSV(_ sender: Any) {
        importPanel.show { (url, type) in
            do {
                try self.dataSource.bulkController.loadTemplate(type: type)
                let resources = try self.dataSource.bulkController.importCSV(from: url)
                let actionName = NSLocalizedString(resources.count == 1 ? "Import Resource" : "Import Resources", comment: "")
                // Allow the sheet to disappear before continuing
                DispatchQueue.main.async {
                    self.add(resources: resources, actionName: actionName)
                }
            } catch let error {
                self.presentError(error)
            }
        }
    }

    // MARK: - Edit Operations

    @IBAction func cut(_ sender: Any) {
        let resources = dataSource.selectedResources(deep: true)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(resources)
        self.remove(resources: resources)
        self.undoManager?.setActionName(NSLocalizedString(resources.count == 1 ? "Cut Resource" : "Cut Resources", comment: ""))
    }

    @IBAction func copy(_ sender: Any) {
        let resources = dataSource.selectedResources(deep: true)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(resources)
    }

    @IBAction func paste(_ sender: Any) {
        if let resources = NSPasteboard.general.readObjects(forClasses: [Resource.self]) as? [Resource] {
            self.add(resources: resources)
        }
    }

    @IBAction func delete(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: RFDefaults.deleteResourceWarning) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Are you sure you want to delete the selected resources?", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Delete", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: self.windowForSheet!) { modalResponse in
                if modalResponse == .alertFirstButtonReturn {
                    self.remove(resources: self.dataSource.selectedResources(deep: true))
                }
            }
        } else {
            self.remove(resources: dataSource.selectedResources(deep: true))
        }
    }

    @IBAction func revertResource(_ sender: Any) {
        for resource in dataSource.selectedResources(deep: true) {
            resource.revertData()
        }
    }

    func add(resources: [Resource], actionName: String? = nil) {
        // Clear type attributes if not supported
        if !format.supportsTypeAttributes {
            for resource in resources {
                resource.typeAttributes = [:]
                resource.id = Int(Int16(clamping: resource.id))
            }
        }
        let resourceMap = ResourceMap(grouping: resources) { $0.type }
        let resolver = ConflictResolver(document: self, multiple: resources.count > 1)
        resourceMap.forEach(resolver.process)
        guard !resolver.toAdd.isEmpty else {
            return
        }
        let actionName = actionName ?? NSLocalizedString(resources.count == 1 ? "Paste Resource" : "Paste Resources", comment: "")
        dataSource.reload(actionName: actionName) {
            directory.remove(resolver.toRemove)
            directory.add(resolver.toAdd)
            return resolver.toAdd
        }
    }

    func changeTypes(resources: [Resource], type: ResourceType) {
        let resolver = ConflictResolver(document: self, multiple: resources.count > 1)
        resolver.process(type: type, resources: resources)
        guard !resolver.toAdd.isEmpty else {
            return
        }
        let actionName = NSLocalizedString(resources.count == 1 ? "Change Type" : "Change Types", comment: "")
        dataSource.reload(actionName: actionName) {
            directory.remove(resolver.toRemove)
            for resource in resolver.toAdd {
                resource.typeCode = type.code
                resource.typeAttributes = type.attributes
            }
            return resolver.toAdd
        }
    }

    func remove(resources: [Resource]) {
        guard !resources.isEmpty else {
            return
        }
        let actionName = NSLocalizedString(resources.count == 1 ? "Delete Resource" : "Delete Resources", comment: "")
        dataSource.reload(actionName: actionName) {
            directory.remove(resources)
            return []
        }
    }
}
