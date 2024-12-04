import AppKit
import RFSupport

class EditorManager: RFEditorManager {
    private var editorWindows: [String: ResourceEditor] = [:]
    private unowned var _document: ResourceDocument?
    var document: NSDocument? { _document }
    static var shared = EditorManager()

    init() {}
    
    init(_ document: ResourceDocument) {
        self._document = document
        NotificationCenter.default.addObserver(self, selector: #selector(resourceRemoved(_:)), name: .DocumentDidRemoveResources, object: document)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
    }
    
    @objc func resourceRemoved(_ notification: Notification) {
        // Close any open editors without saving
        guard let resources = notification.userInfo?["resources"] as? [Resource] else {
            return
        }
        for (_, plug) in editorWindows where resources.contains(plug.resource) {
            plug.close()
        }
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        if let plug = (notification.object as? NSWindow)?.delegate as? ResourceEditor {
            for (key, value) in editorWindows where value === plug {
                editorWindows.removeValue(forKey: key)
            }
        }
    }
    
    func closeAll(saving: Bool) -> Bool {
        for (_, plug) in editorWindows {
            if saving {
                plug.window?.performClose(self)
            } else {
                plug.close()
            }
            if plug.window?.isVisible ?? false {
                return false
            }
        }
        return true
    }

    func template(for type: ResourceType?, basic: Bool = false) -> Resource? {
        guard let type else {
            return nil
        }
        return self.findResource(type: basic ? .basicTemplate : .template, name: type.code)
    }
    
    private func mappedType(for resource: Resource, forEditor: Bool) -> ResourceType? {
        do {
            guard let rmapResource = findResource(type: ResourceType("RMAP"), name: resource.type.code) else { return nil }
            let reader = BinaryDataReader(rmapResource.data)
            let destinationType = try reader.readString(length: 4, encoding: .macOSRoman)
            let editorOnly: UInt16 = try reader.read()
            var exceptionCount: UInt16 = try reader.read()
            while exceptionCount > 0 {
                let exceptionResID: Int16 = try reader.read()
                let exceptionDestinationType = try reader.readString(length: 4, encoding: .macOSRoman)
                let exceptionEditorOnly: UInt16 = try reader.read()
                
                if resource.id == exceptionResID,
                   forEditor || exceptionEditorOnly == 0 {
                    return ResourceType(exceptionDestinationType)
                }
                
                exceptionCount -= 1
            }
            if forEditor || editorOnly == 0 {
                return ResourceType(destinationType)
            }
        } catch {
        }
        return nil
    }

    func image(for type: ResourceType) -> NSImage? {
        guard #available(macOS 11, *) else {
            return nil
        }

        if let icon = PluginRegistry.icon(for: type) {
            if icon.count == 1 {
                // Render a single character as an image
                return NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
                    (icon as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
                    return true
                }
            } else if let image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
                return image
            }
        }

        // Use a default icon according to whether we have a template or not
        let hasTemplate = self.template(for: type) != nil
        return NSImage(systemSymbolName: hasTemplate ? "doc.plaintext" : "01.square", accessibilityDescription: nil)
    }

    // MARK: - Protocol functions
    
    func open(resource: Resource) {
        // If the resource belongs to a different document, make sure we use that document's editor
        // manager to open it. If the resource has no document (e.g. it's from the support registry)
        // then it's okay to track it with the current manager, closing it when our document closes.
        if let rDoc = resource.document as? ResourceDocument, rDoc != _document {
            rDoc.editorManager.open(resource: resource, as: nil)
            return
        }
        open(resource: resource, as: nil)
    }
    
    private func open(resource: Resource, as type: ResourceType?) {
        if let editor = PluginRegistry.editors[(type ?? resource.type).code] {
            self.open(resource: resource, using: editor, template: nil)
        } else if let template = self.template(for: type ?? resource.type) {
            self.open(resource: resource, using: TemplateEditor.self, template: template)
        } else if type == nil, let mappedType = mappedType(for: resource, forEditor: true) {
            open(resource: resource, as: mappedType)
        } else {
            self.open(resource: resource, using: PluginRegistry.hexEditor, template: nil)
        }
    }
    
    func open(resource: Resource, using editor: ResourceEditor.Type) {
        self.open(resource: resource, using: editor, template: nil)
    }
    
    func open(resource: Resource, using editor: ResourceEditor.Type, template: Resource?) {
        // Keep track of opened resources so we don't open them multiple times
        let key = String(describing: resource).appending(String(describing: editor))
        var plug = editorWindows[key]
        if plug == nil {
            if let editor = editor as? TemplateEditor.Type, let template {
                let filter = PluginRegistry.templateFilters[resource.typeCode]
                plug = editor.init(resource: resource, manager: self, template: template, filter: filter)
            } else {
                plug = editor.init(resource: resource, manager: self)
            }
            if plug == nil {
                return
            }
            editorWindows[key] = plug
        }
        if let plug {
            // Make sure the plug is the window's delegate
            plug.window?.delegate = plug
            plug.showWindow(self)
        }
    }
    
    func allResources(ofType type: ResourceType, currentDocumentOnly: Bool = false) -> [Resource] {
        var resources = _document?.directory.resources(ofType: type) ?? []
        if !currentDocumentOnly {
            for doc in ResourceDocument.all() where doc !== _document {
                resources += doc.directory.resources(ofType: type)
            }
            resources += SupportRegistry.directory.resources(ofType: type)
        }
        return resources
    }
    
    func findResource(type: ResourceType, id: Int, currentDocumentOnly: Bool = false) -> Resource? {
        if let resource = _document?.directory.findResource(type: type, id: id) {
            return resource
        }
        if !currentDocumentOnly {
            for doc in ResourceDocument.all() where doc !== _document {
                if let resource = doc.directory.findResource(type: type, id: id) {
                    return resource
                }
            }
        }
        return SupportRegistry.directory.findResource(type: type, id: id)
    }
    
    func findResource(type: ResourceType, name: String, currentDocumentOnly: Bool = false) -> Resource? {
        if let resource = _document?.directory.findResource(type: type, name: name) {
            return resource
        }
        if !currentDocumentOnly {
            for doc in ResourceDocument.all() where doc !== _document {
                if let resource = doc.directory.findResource(type: type, name: name) {
                    return resource
                }
            }
        }
        return SupportRegistry.directory.findResource(type: type, name: name)
    }
    
    func createResource(type: ResourceType, id: Int?, name: String, callback: ((Resource) -> Void)? = nil) {
        // The create modal will bring the document window to the front
        // Remember the current main window so we can restore it afterward
        weak var window = NSApp.mainWindow
        // Ignore id if -1 or 0
        let id = id == -1 || id == 0 ? nil : id
        _document?.createController.show(type: type, id: id, name: name) { resource in
            window?.makeKeyAndOrderFront(nil)
            if let resource {
                self.open(resource: resource)
                // Only callback if the type was not changed
                if resource.type == type {
                    callback?(resource)
                }
            }
        }
    }
}
