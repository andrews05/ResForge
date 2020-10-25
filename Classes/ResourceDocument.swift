import Cocoa
import RKSupport

extension Notification.Name {
    static let DocumentInfoDidChange        = Self("DocumentInfoDidChange")
    static let DocumentSelectionDidChange   = Self("DocumentSelectionDidChange")
}

class ResourceDocument: NSDocument, NSToolbarItemValidation, NSWindowDelegate, NSDraggingDestination {
    @IBOutlet var dataSource: ResourceDataSource!
    private(set) lazy var directory = ResourceDirectory(self)
    private(set) lazy var editorManager = EditorManager(self)
    private(set) lazy var createController = CreateResourceController(self)
    private var fork: String!
    private var format: ResourceFileFormat = kFormatClassic
    var hfsType: OSType = 0 {
        didSet {
            if hfsType != oldValue {
                NotificationCenter.default.post(name: .DocumentInfoDidChange, object: self)
                self.undoManager?.setActionName(NSLocalizedString("Change File Type", comment: ""))
                self.undoManager?.registerUndo(withTarget: self, handler: { $0.hfsType = oldValue })
            }
        }
    }
    var hfsCreator: OSType = 0 {
        didSet {
            if hfsCreator != oldValue {
                NotificationCenter.default.post(name: .DocumentInfoDidChange, object: self)
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
        
        // Work out which fork to parse
        // Note: If we are reverting the document, fork will already be set and we won't be able to get it from the open panel again
        if fork == nil {
            fork = (NSDocumentController.shared as! OpenPanelDelegate).getSelectedFork()
        }
        var resources: [Resource]?
        if let fork = fork {
            // If fork was sepcified in open panel, try this fork only
            if fork == "" && hasData {
                resources = try ResourceFile.read(from: url, format: &format)
            } else if fork == "rsrc" && hasRsrc {
                resources = try ResourceFile.read(from: rsrcURL, format: &format)
            } else {
                // Fork is empty
                resources = []
            }
        } else {
            // Try to open data fork
            if hasData {
                do {
                    resources = try ResourceFile.read(from: url, format: &format)
                    fork = ""
                } catch {}
            }
            // If failed, try resource fork
            if resources == nil && hasRsrc {
                do {
                    resources = try ResourceFile.read(from: rsrcURL, format: &format)
                    fork = "rsrc"
                } catch {}
            }
            // If still failed, find an empty fork
            if resources == nil && !hasData {
                resources = []
                fork = ""
            } else if resources == nil && !hasRsrc {
                resources = []
                fork = "rsrc"
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
    
    override func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        if saveOperation == .saveAsOperation {
            // Set fork according to typeName
            if typeName == "ResourceMapRF" {
                format = kFormatClassic
                fork = "rsrc"
                // Set default type/creator for resource fork only
                if hfsType == 0 && hfsCreator == 0 {
                    hfsType = OSType("rsrc")
                    hfsCreator = OSType("ResK")
                }
            } else {
                format = typeName == "ResourceMapExtended" ? kFormatExtended : kFormatClassic
                fork = ""
                // Clear type/creator for data fork (assume filename extension)
                hfsType = 0
                hfsCreator = 0
            }
        }
        
        // Create file
        // Note: Doesn't preserve any other FinderInfo properties from the old file
        var attrs: [FileAttributeKey: Any]?
        if hfsType != 0 || hfsCreator != 0 {
            attrs = [.hfsTypeCode: hfsType, .hfsCreatorCode: hfsCreator]
        }
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: attrs)
        
        // Write resources to file
        let writeUrl = fork == "rsrc" ? url.appendingPathComponent("..namedfork/rsrc") : url
        try ResourceFile.write(directory.resources(), to: writeUrl, with: format)
        
        // If writing the resource fork, copy the data from the old file
        if saveOperation == .saveOperation && fork == "rsrc" {
            let err = copyfile(absoluteOriginalContentsURL?.path.cString(using: .utf8), url.path.cString(using: .utf8), nil, copyfile_flags_t(COPYFILE_DATA))
            if err != noErr {
                throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: nil)
            }
        }
        
        // Update info window
        NotificationCenter.default.post(name: .DocumentInfoDidChange, object: self)
    }
    
    // MARK: - Export
    
    @IBAction func exportResources(_ sender: Any?) {
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
                if modalResponse == .OK {
                    for resource in resources {
                        let filename = self.filenameForExport(resource: resource)
                        var url = panel.url!.appendingPathComponent(filename.name).appendingPathExtension(filename.ext)
                        // Ensure unique name
                        var i = 2
                        while FileManager.default.fileExists(atPath: url.path) {
                            url = panel.url!.appendingPathComponent("\(filename.name) \(i)").appendingPathExtension(filename.ext)
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
                if modalResponse == .OK {
                    self.export(resource: resource, to: panel.url!)
                }
            }
        }
    }
    
    private func filenameForExport(resource: Resource) -> (name: String, ext: String) {
        var filename = resource.name.replacingOccurrences(of: "/", with: ":")
        if filename == "" {
            filename = "\(resource.type) \(resource.id)"
        }
        let editor = PluginRegistry.editors[resource.type]
        let ext = editor?.filenameExtension?(for: resource.type) ?? resource.type.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return (filename, ext)
    }
    
    private func export(resource: Resource, to url: URL) {
        let editor = PluginRegistry.editors[resource.type]
        do {
            try editor?.export?(resource, to: url) ?? resource.data.write(to: url)
        } catch {}
    }
    
    // MARK: - Window Management
    
    override func windowControllerDidLoadNib(_ windowController: NSWindowController) {
        windowController.window?.registerForDraggedTypes([.RKResource])
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
        default:
            // Auto validation of save menu item isn't working for existing documents - force override
            if menuItem.identifier?.rawValue == "save" {
                return self.isDocumentEdited
            }
            return super.validateMenuItem(menuItem)
        }
    }
    
    // FIXME: This function is for image-type items only - a new solution is needed for button types
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.action {
        case #selector(delete(_:)),
            #selector(openResources(_:)),
            #selector(openResourcesInTemplate(_:)),
            #selector(openResourcesAsHex(_:)),
            #selector(exportResources(_:)):
            return dataSource.selectionCount() > 0
        default:
            return true
        }
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        self.updateSidebarMenuTitle()
    }
    
    private func updateSidebarMenuTitle() {
        let item = NSApp.mainMenu?.item(withTitle: "View")?.submenu?.item(withTag: 1)
        item?.title = NSLocalizedString(dataSource.useTypeList ? "Hide Sidebar" : "Show Sidebar", comment: "")
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
        SelectTemplateController().show(self, type: resources.first!.type) { template in
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
        self.updateSidebarMenuTitle()
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
        if UserDefaults.standard.bool(forKey: "DeleteResourceWarning") {
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
        guard resources.count > 0 else {
            return
        }
        dataSource.reload {
            var added: [Resource] = []
            var alert: NSAlert!
            var modalResponse: NSApplication.ModalResponse?
            for resource in resources {
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
                        alert.messageText = String(format: NSLocalizedString("A resource of type '%@' with ID %ld already exists.", comment: ""), resource.type, resource.id)
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
        guard resources.count > 0 else {
            return
        }
        dataSource.reload {
            for resource in resources {
                directory.remove(resource)
            }
            return nil
        }
        self.undoManager?.setActionName(NSLocalizedString(resources.count == 1 ? "Delete Resource" : "Delete Resources", comment: ""))
    }
}
