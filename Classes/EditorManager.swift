import Cocoa
import RKSupport

class EditorManager: NSObject, NSWindowDelegate, ResKnifePluginManager {
    private var editorWindows: [String: ResKnifePlugin] = [:]
    private weak var document: ResourceDocument!
    
    init(_ document: ResourceDocument) {
        self.document = document
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(resourceRemoved(_:)), name: .DirectoryDidRemoveResource, object: document.directory)
    }
    
    @objc func resourceRemoved(_ notification: Notification) {
        // Close any open editors without saving
        let resource = notification.userInfo!["resource"] as! Resource
        for (_, value) in editorWindows where value.resource === resource {
            if let plug = value as? NSWindowController {
                plug.close()
            }
        }
    }
    
    func closeAll(saving: Bool) -> Bool {
        for (_, value) in editorWindows {
            if let plug = value as? NSWindowController {
                if saving {
                    plug.window?.performClose(self)
                } else {
                    plug.close()
                }
                if plug.window?.isVisible ?? false {
                    return false
                }
            }
        }
        return true
    }
    
    // This is called when closing editor windows. It provides a common save process, with confirmation
    // according to the user preferences, so that plugins don't have to handle this themselves.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil) // Ensure any controls have ended editing
        if sender.isDocumentEdited {
            let plug = sender.windowController as! ResKnifePlugin
            if UserDefaults.standard.bool(forKey: kConfirmChanges) {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Do you want to keep the changes you made to this resource?", comment: "")
                alert.informativeText = NSLocalizedString("Your changes cannot be saved later if you don't keep them.", comment: "")
                alert.addButton(withTitle: NSLocalizedString("Keep", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Don't Keep", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                alert.beginSheetModal(for: sender) { returnCode in
                    switch (returnCode) {
                    case .alertFirstButtonReturn: // keep
                        plug.saveResource(alert)
                        sender.close()
                    case .alertSecondButtonReturn: // don't keep
                        sender.close()
                    default:
                        break
                    }
                }
                return false
            }
            plug.saveResource(sender)
        }
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        let plug = (notification.object as! NSWindow).windowController as! ResKnifePlugin
        for (key, value) in editorWindows where value === plug {
            editorWindows.removeValue(forKey: key)
        }
    }
    
    // MARK: - Protocol functions
    
    func open(resource: Resource, using editor: ResKnifePlugin.Type? = nil, template: String? = nil) {
        // Work out editor to use
        var editor = editor ?? PluginRegistry.editors[resource.type] ?? PluginRegistry.templateEditor
        var tmplResource: Resource!
        if editor is ResKnifeTemplatePlugin.Type {
            // If template editor, find the template to use
            tmplResource = self.findResource(ofType: "TMPL", name: template ?? resource.type)
            // If no template, switch to hex editor
            if tmplResource == nil {
                editor = PluginRegistry.hexEditor
            }
        }
        
        // Keep track of opened resources so we don't open them multiple times
        let key = String(describing: resource).appending(String(describing: editor))
        var plug = editorWindows[key]
        if plug == nil {
            // Set a reference to the manager on the resource. This allows the plugin to access the manager and call the protocol functions.
            resource.manager = self
            if let editor = editor as? ResKnifeTemplatePlugin.Type {
                plug = editor.init(resource: resource, template: tmplResource)
            } else {
                plug = editor!.init(resource: resource)
            }
            if plug == nil {
                return
            }
            editorWindows[key] = plug
        }
        if let plug = plug as? NSWindowController {
            // We want to control the windowShouldClose function
            plug.window?.delegate = self
            plug.showWindow(self)
        }
    }
    
    func allResources(ofType type: String, currentDocumentOnly: Bool = false) -> [Resource] {
        var resources = document.directory.resources(ofType: type)
        if !currentDocumentOnly {
            let docs = NSDocumentController.shared.documents as! [ResourceDocument]
            for doc in docs where doc !== document {
                resources.append(contentsOf: doc.directory.resources(ofType: type))
            }
        }
        return resources
    }

    func findResource(ofType type: String, id: Int, currentDocumentOnly: Bool = false) -> Resource? {
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

    func findResource(ofType type: String, name: String, currentDocumentOnly: Bool = false) -> Resource? {
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
    
    func createResource(ofType: String, id: Int, name: String) {
        document.createController.show(type: ofType, id: id, name: name)
    }
}
