import Cocoa
import RFSupport

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

extension ResourceFileFormat {
    var name: String {
        switch self {
        case .classic:
            return NSLocalizedString("Resource File", comment: "")
        case .extended:
            return NSLocalizedString("Extended Resource File", comment: "")
        case .rez:
            return NSLocalizedString("Rez File", comment: "")
        @unknown default:
            return ""
        }
    }
    var minID: Int {
        self == .extended ? Int(Int32.min) : Int(Int16.min)
    }
    var maxID: Int {
        self == .extended ? Int(Int32.max) : Int(Int16.max)
    }
}

class ResourceDocument: NSDocument, NSWindowDelegate, NSDraggingDestination, NSToolbarDelegate {
    @IBOutlet var dataSource: ResourceDataSource!
    @IBOutlet var statusText: NSTextField!
    private(set) lazy var directory = ResourceDirectory(self)
    private(set) lazy var editorManager = EditorManager(self)
    private(set) lazy var createController = CreateResourceController(self)
    private var fork: FileFork!
    private(set) var format: ResourceFileFormat = .classic
    
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

    override var windowNibName: String {
        return "ResourceDocument"
    }
    
    // MARK: - File Management
    
    override func read(from url: URL, ofType typeName: String) throws {
        let rsrcURL = url.appendingPathComponent("..namedfork/rsrc")
        
        // Find out which forks have data
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        let hasData = values.fileSize! > 0
        let hasRsrc = (values.totalFileSize! - values.fileSize!) > 0
        
        // Work out which fork to parse. If we are opening the document for the first time, attempt to get fork from the open panel.
        if fork == nil {
            fork = (NSDocumentController.shared as! OpenPanelDelegate).getSelectedFork()
        }
        var resources: [Resource]?
        if let fork = fork {
            // If fork has been set, try this fork only
            if fork == .data && hasData {
                resources = try ResourceFile.read(from: url, format: &format)
            } else if fork == .rsrc && hasRsrc {
                resources = try ResourceFile.read(from: rsrcURL, format: &format)
            } else {
                // Fork is empty
                resources = []
            }
        } else {
            // If resource fork exists, try it first
            if hasRsrc {
                do {
                    resources = try ResourceFile.read(from: rsrcURL, format: &format)
                    fork = .rsrc
                } catch {}
            }
            // If failed, try data fork
            if resources == nil && hasData {
                do {
                    resources = try ResourceFile.read(from: url, format: &format)
                    fork = .data
                } catch {}
            }
            // If still failed, find an empty fork
            if resources == nil && !hasData {
                resources = []
                fork = .data
            } else if resources == nil && !hasRsrc {
                resources = []
                fork = .rsrc
            }
        }
        
        if let resources = resources {
            // Get type and creator - make sure undo registration is disabled while configuring
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            self.undoManager?.disableUndoRegistration()
            _ = editorManager.closeAll(saving: false)
            hfsType = attrs[.hfsTypeCode] as! OSType
            hfsCreator = attrs[.hfsCreatorCode] as! OSType
            directory.reset()
            directory.add(resources)
            dataSource?.reload()
            self.undoManager?.enableUndoRegistration()
        } else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError, userInfo: nil)
        }
    }
    
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        if savePanel.nameFieldStringValue == self.defaultDraftName() {
            savePanel.nameFieldStringValue = self.defaultDraftName().appending(".rsrc")
        }
        return super.prepareSavePanel(savePanel)
    }
    
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        if saveOperation == .saveOperation && fork == .rsrc, let fileURL = self.fileURL {
            // In place save of resource fork. We want to preserve all other aspects of the file, such as the data fork and finder flags.
            // Relying on the default implementation can result in some oddities, so instead we'll just write out the resource fork directly.
            // This isn't strictly "safe", although Graphite's writer will at least detect structural issues before writing any data.
            // First we need to check if the file is being renamed for some reason and copy the existing file to the new location.
            let moved = fileURL != url
            if moved {
                try FileManager.default.copyItem(at: fileURL, to: url)
            }
            do {
                let writeUrl = url.appendingPathComponent("..namedfork/rsrc")
                try ResourceFile.write(directory.resources(), to: writeUrl, as: format)
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
        
        // Update info window
        NotificationCenter.default.post(name: .DocumentInfoDidChange, object: self)
        self.updateStatus()
    }
    
    override func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        var format = format
        var fork = fork
        var hfsType = hfsType
        var hfsCreator = hfsCreator
        if saveOperation == .saveAsOperation {
            // Set fork according to typeName
            if typeName == "ResourceFileRF" {
                format = .classic
                fork = .rsrc
            } else {
                format = typeName == "ResourceFileExtended" ? .extended : .classic
                fork = .data
                // Clear type/creator for data fork (assume filename extension)
                hfsType = 0
                hfsCreator = 0
            }
        }
        
        // Create file (this is important to be done first if we're writing the resource fork)
        // Type codes should only be set if not blank, to avoid unnecessarily creating the FinderInfo
        var attrs: [FileAttributeKey: Any]?
        if hfsType != 0 || hfsCreator != 0 {
            attrs = [.hfsTypeCode: hfsType, .hfsCreatorCode: hfsCreator]
        }
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: attrs)
        
        // Write resources to file
        let writeUrl = fork == .rsrc ? url.appendingPathComponent("..namedfork/rsrc") : url
        try ResourceFile.write(directory.resources(), to: writeUrl, as: format)
        
        // Save any properties that may have changed (only do this after successful write)
        self.undoManager?.disableUndoRegistration()
        self.format = format
        self.fork = fork
        self.hfsType = hfsType
        self.hfsCreator = hfsCreator
        self.undoManager?.enableUndoRegistration()
    }
    
    // MARK: - Export
    
    @IBAction func exportResources(_ sender: Any) {
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
                        let filename = self.filenameForExport(resource: resource)
                        var url = saveDir.appendingPathComponent(filename.name).appendingPathExtension(filename.ext)
                        // Ensure unique name
                        var i = 2
                        while FileManager.default.fileExists(atPath: url.path) {
                            url = saveDir.appendingPathComponent("\(filename.name) \(i)").appendingPathExtension(filename.ext)
                            i = i + 1
                        }
                        self.export(resource: resource, to: url)
                    }
                }
            }
        } else if resources.count == 1 {
            // Single resource, show save panel
            let resource = resources.first!
            let panel = NSSavePanel()
            let filename = self.filenameForExport(resource: resource)
            panel.nameFieldStringValue = "\(filename.name).\(filename.ext)"
            panel.beginSheetModal(for: self.windowForSheet!) { modalResponse in
                if modalResponse == .OK, let url = panel.url {
                    self.export(resource: resource, to: url)
                }
            }
        }
    }
    
    private func filenameForExport(resource: Resource) -> (name: String, ext: String) {
        var filename = resource.name.replacingOccurrences(of: "/", with: ":")
        if filename == "" {
            filename = "\(resource.typeCode) \(resource.id)"
        }
        let editor = PluginRegistry.exportProviders[resource.typeCode]
        let ext = editor?.filenameExtension(for: resource.typeCode) ?? resource.typeCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return (filename, ext)
    }
    
    private func export(resource: Resource, to url: URL) {
        do {
            if resource.data.isEmpty {
                try Data().write(to: url)
            } else {
                let editor = PluginRegistry.exportProviders[resource.typeCode]
                if try editor?.export(resource, to: url) != true {
                    try resource.data.write(to: url)
                }
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
        if #available(OSX 11.0, *) {
            defaults.removeFirst(.space)
        }
        return defaults
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        // Create the toolbar items. On macOS 11 we use the special search toolbar item as well as the system symbol images.
        let item: NSToolbarItem
        if itemIdentifier == .searchField {
            if #available(OSX 11.0, *) {
                item = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
                (item as! NSSearchToolbarItem).preferredWidthForSearchField = 180
            } else {
                item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.view = NSSearchField()
                item.label = NSLocalizedString("Search", comment: "")
                item.minSize = NSMakeSize(120, 0)
                item.maxSize = NSMakeSize(180, 0)
            }
            item.action = #selector(ResourceDataSource.filter(_:))
            item.target = dataSource
            return item
        }
        
        item = NSToolbarItem(itemIdentifier: itemIdentifier)
        let button = NSButton(frame: NSMakeRect(0, 0, 36, 0))
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
            if #available(OSX 11.0, *) {
                item.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
            } else {
                item.image = NSImage(named: "trash")
            }
            item.action = #selector(delete(_:))
            item.isEnabled = false
        case .editResource:
            item.label = NSLocalizedString("Edit", comment: "")
            if #available(OSX 11.0, *) {
                item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)
            } else {
                item.image = NSImage(named: "square.and.pencil")
            }
            item.action = #selector(openResources(_:))
            item.isEnabled = false
        case .editHex:
            item.label = NSLocalizedString("Edit Hex", comment: "")
            if #available(OSX 11.0, *) {
                item.image = NSImage(systemSymbolName: "rectangle.and.pencil.and.ellipsis", accessibilityDescription: nil)
            } else {
                item.image = NSImage(named: "rectangle.and.pencil.and.ellipsis")
            }
            item.action = #selector(openResourcesAsHex(_:))
            item.isEnabled = false
        case .exportResources:
            item.label = NSLocalizedString("Export", comment: "")
            item.image = NSImage(named: NSImage.shareTemplateName)
            item.action = #selector(exportResources(_:))
            item.isEnabled = false
        case .showInfo:
            item.label = NSLocalizedString("Show Info", comment: "")
            if #available(OSX 11.0, *) {
                item.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
            } else {
                item.image = NSImage(named: "info.circle")
            }
            item.target = NSApp.delegate
            item.action = #selector(ApplicationDelegate.showInfo(_:))
        default:
            break
        }
        return item
    }
    
    func toolbarWillAddItem(_ notification: Notification) {
        // Set the sidebar toggle target to self
        if let addedItem = notification.userInfo?["item"] as? NSToolbarItem, addedItem.itemIdentifier == .toggleSidebar {
            addedItem.target = self
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
    
    // MARK: - Window Management
    
    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        windowController.window?.registerForDraggedTypes([.RKResource])
        self.updateStatus()
        NotificationCenter.default.addObserver(self, selector: #selector(validateToolbarItems(_:)), name: .DocumentSelectionDidChange, object: self)
        if #available(OSX 11.0, *) {
            (statusText.superview?.superview as? NSBox)?.fillColor = .windowBackgroundColor
        }
    }
    
    func updateStatus() {
        guard let statusText = statusText else {
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
        if let fork = fork {
            var formatName = format.name
            if format == .classic || fork == .rsrc {
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
        if let resources = sender.draggingPasteboard.readObjects(forClasses: [Resource.self], options: nil) as? [Resource] {
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
            #selector(exportResources(_:)):
            return dataSource.selectionCount() > 0
        case #selector(toggleSidebar(_:)):
            menuItem.title = NSLocalizedString(dataSource.useTypeList ? "Hide Sidebar" : "Show Sidebar", comment: "")
            return true
        case #selector(toggleBulkMode(_:)):
            if dataSource.isBulkMode {
                menuItem.title = NSLocalizedString("Exit Bulk Data Mode", comment: "")
                return true
            }
            menuItem.title = NSLocalizedString("Bulk Data Mode", comment: "")
            if let type = dataSource.currentType {
                return dataSource.bulkController.supports(type: type)
            }
            return false
        case #selector(exportCSV(_:)):
            if #available(OSX 10.14, *) {
                if let type = dataSource.currentType {
                    menuItem.title = NSLocalizedString("Export ‘\(type.code)’ to CSV…", comment: "")
                    return dataSource.bulkController.supports(type: type)
                }
                menuItem.title = NSLocalizedString("Export to CSV…", comment: "")
            }
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
    
    @IBAction func openResources(_ sender: NSObject) {
        for resource in dataSource.selectedResources() {
            editorManager.open(resource: resource)
        }
    }
    
    @IBAction func openResourcesInTemplate(_ sender: Any) {
        let resources = dataSource.selectedResources()
        guard !resources.isEmpty else {
            return
        }
        SelectTemplateController().show(self, typeCode: resources.first!.typeCode) { template in
            for resource in resources {
                self.editorManager.open(resource: resource, using: PluginRegistry.templateEditor, template: template)
            }
        }
    }
    
    @IBAction func openResourcesAsHex(_ sender: Any) {
        for resource in dataSource.selectedResources() {
            editorManager.open(resource: resource, using: PluginRegistry.hexEditor)
        }
    }
    
    @IBAction func toggleSidebar(_ sender: Any) {
        dataSource.toggleSidebar()
    }
    
    @IBAction func toggleBulkMode(_ sender: Any) {
        dataSource.toggleBulkMode()
    }
    
    @IBAction func exportCSV(_ sender: Any) {
        guard #available(OSX 10.14, *), let type = dataSource.currentType else {
            return
        }
        do {
            _ = try dataSource.bulkController.loadTemplate()
        } catch let error {
            self.presentError(error)
        }
        let panel = NSSavePanel()
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
    
    // MARK: - Edit Operations
    
    @IBAction func cut(_ sender: Any) {
        let resources = dataSource.selectedResources(deep: true)
        let pb = NSPasteboard.init(name: .generalPboard)
        pb.declareTypes([.RKResource], owner: self)
        pb.writeObjects(resources)
        self.remove(resources: resources)
        self.undoManager?.setActionName(NSLocalizedString(resources.count == 1 ? "Cut Resource" : "Cut Resources", comment: ""))
    }
    
    @IBAction func copy(_ sender: Any) {
        let pb = NSPasteboard(name: .generalPboard)
        pb.declareTypes([.RKResource], owner: self)
        pb.writeObjects(dataSource.selectedResources(deep: true))
    }
    
    @IBAction func paste(_ sender: Any) {
        let pb = NSPasteboard(name: .generalPboard)
        self.add(resources: pb.readObjects(forClasses: [Resource.self], options: nil) as! [Resource])
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
    
    func add(resources: [Resource]) {
        guard !resources.isEmpty else {
            return
        }
        dataSource.reload {
            var added: [Resource] = []
            var alert: NSAlert!
            var modalResponse: NSApplication.ModalResponse?
            for resource in resources {
                // Clear type attributes if not extended format
                if format != .extended {
                    resource.typeAttributes = [:]
                    resource.id = Int(Int16(clamping: resource.id))
                }
                if let conflicted = directory.findResource(type: resource.type, id: resource.id) {
                    // Resource slot is occupied, ask user what to do
                    if modalResponse == nil {
                        if alert == nil {
                            alert = NSAlert()
                            alert.informativeText = NSLocalizedString("Do you wish to assign the new resource a unique ID, overwrite the existing resource, or skip this resource?", comment: "")
                            alert.addButton(withTitle: NSLocalizedString("Unique ID", comment: ""))
                            alert.addButton(withTitle: NSLocalizedString("Overwrite", comment: ""))
                            alert.addButton(withTitle: NSLocalizedString("Skip", comment: ""))
                            // Show apply to all checkbox when there are multiple resources
                            alert.showsSuppressionButton = resources.count > 1
                            alert.suppressionButton?.title = NSLocalizedString("Apply to all", comment: "")
                        }
                        alert.messageText = String(format: NSLocalizedString("A resource of type ‘%@’ with ID %ld already exists.", comment: ""), resource.typeCode, resource.id)
                        // TODO: Do this in a non-blocking way?
                        alert.beginSheetModal(for: self.windowForSheet!) { modalResponse in
                            NSApp.stopModal(withCode: modalResponse)
                        }
                        modalResponse = NSApp.runModal(for: alert.window)
                    }
                    switch (modalResponse!) {
                    case .alertFirstButtonReturn: // unique id
                        resource.id = directory.uniqueID(for: resource.type, starting: resource.id)
                        directory.add(resource)
                        added.append(resource)
                    case .alertSecondButtonReturn: // overwrite
                        directory.remove(conflicted)
                        directory.add(resource)
                        added.append(resource)
                    default:
                        break
                    }
                    // If suppression button was not checked, clear the response (otherwise remember it for next time)
                    if alert.suppressionButton?.state == .off {
                        modalResponse = nil
                    }
                } else {
                    directory.add(resource)
                    added.append(resource)
                }
            }
            return added
        }
        self.undoManager?.setActionName(NSLocalizedString(resources.count == 1 ? "Paste Resource" : "Paste Resources", comment: ""))
    }
    
    func remove(resources: [Resource]) {
        guard !resources.isEmpty else {
            return
        }
        dataSource.reload {
            for resource in resources {
                directory.remove(resource)
            }
            return []
        }
        self.undoManager?.setActionName(NSLocalizedString(resources.count == 1 ? "Delete Resource" : "Delete Resources", comment: ""))
    }
}
