import Cocoa
import RFSupport

class EditorManager: RFEditorManager {
    private var editorWindows: [String: ResourceEditor] = [:]
    private unowned var document: ResourceDocument
    
    init(_ document: ResourceDocument) {
        self.document = document
        NotificationCenter.default.addObserver(self, selector: #selector(resourceRemoved(_:)), name: .DirectoryDidRemoveResource, object: document.directory)
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(_:)), name: NSWindow.willCloseNotification, object: nil)
    }
    
    @objc func resourceRemoved(_ notification: Notification) {
        // Close any open editors without saving
        let resource = notification.userInfo!["resource"] as! Resource
        for (_, plug) in editorWindows where plug.resource === resource {
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
        guard let type = type else {
            return nil
        }
        return self.findResource(type: basic ? PluginRegistry.basicTemplateType : PluginRegistry.templateType, name: type.code)
    }
    
    // MARK: - Protocol functions
    
    func open(resource: Resource) {
        if let editor = PluginRegistry.editors[resource.typeCode] {
            self.open(resource: resource, using: editor, template: nil)
        } else if let template = self.template(for: resource.type) {
            self.open(resource: resource, using: PluginRegistry.templateEditor, template: template)
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
            if let editor = editor as? TemplateEditor.Type, let template = template {
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
        if let plug = plug {
            // Make sure the plug is the window's delegate
            plug.window?.delegate = plug
            plug.showWindow(self)
        }
    }
    
    func allResources(ofType type: ResourceType, currentDocumentOnly: Bool = false) -> [Resource] {
        var resources = document.directory.resources(ofType: type)
        if !currentDocumentOnly {
            let docs = NSDocumentController.shared.documents as! [ResourceDocument]
            for doc in docs where doc !== document {
                resources.append(contentsOf: doc.directory.resources(ofType: type))
            }
        }
        return resources
    }

    func findResource(type: ResourceType, id: Int, currentDocumentOnly: Bool = false) -> Resource? {
        if let resource = document.directory.findResource(type: type, id: id) {
            return resource
        }
        if !currentDocumentOnly {
            let docs = NSDocumentController.shared.documents as! [ResourceDocument]
            for doc in docs where doc !== document {
                if let resource = doc.directory.findResource(type: type, id: id) {
                    return resource
                }
            }
        }
        return SupportRegistry.directory.findResource(type: type, id: id)
    }

    func findResource(type: ResourceType, name: String, currentDocumentOnly: Bool = false) -> Resource? {
        if let resource = document.directory.findResource(type: type, name: name) {
            return resource
        }
        if !currentDocumentOnly {
            let docs = NSDocumentController.shared.documents as! [ResourceDocument]
            for doc in docs where doc !== document {
                if let resource = doc.directory.findResource(type: type, name: name) {
                    return resource
                }
            }
        }
        return SupportRegistry.directory.findResource(type: type, name: name)
    }
    
    func createResource(type: ResourceType, id: Int, name: String) {
        document.createController.show(type: type, id: id, name: name)
    }
}
