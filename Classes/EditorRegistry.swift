/*
 This is a registry where all our resource-editor plugins are looked
 up and entered in a list, so you can ask for the editor for a specific
 resource type and it is returned immediately. This registry reads the
 types a plugin handles from their info.plist.
 */

import Foundation

class EditorRegistry: NSObject, NSWindowDelegate {
    private static var registry: [String: ResKnifePlugin.Type] = [:]
    private var editorWindows: [String: ResKnifePlugin] = [:]
    
    @objc static func editor(for type: String) -> ResKnifePlugin.Type? {
        return registry[type]
    }
    
    @objc func open(resource: Resource, using editor: ResKnifePlugin.Type, template: Resource? = nil) -> ResKnifePlugin {
        // Keep track of opened resources so we don't open them multiple times
        let key = resource.description.appending(String(describing: editor))
        var plug = editorWindows[key]
        if plug == nil {
            if let template = template, let editor = editor as? ResKnifeTemplatePlugin.Type {
                plug = editor.init(resource: resource, template: template)
            } else {
                plug = editor.init(resource: resource)
            }
            editorWindows[key] = plug
        }
        if let plug = plug as? NSWindowController {
            // We want to control the windowShouldClose function
            plug.window?.delegate = self
            plug.showWindow(self)
        }
        return plug!
    }
    
    @objc func closeAll() -> Bool {
        for (_, value) in editorWindows {
            if let plug = value as? NSWindowController {
                plug.window?.performClose(self)
                if plug.window?.isVisible ?? false {
                    return false
                }
            }
        }
        return true
    }
    
    static func scanForPlugins() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        for url in appSupport {
            self.scan(folder: url.appendingPathComponent("ResKnife/Plugins"))
        }
        if let plugins = Bundle.main.builtInPlugInsURL {
            self.scan(folder: plugins)
        }
    }
    
    private static func scan(folder: URL) {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            return
        }
        for item in items {
            guard
                item.pathExtension == "plugin",
                let plugin = Bundle(url: item),
                let pluginClass = plugin.principalClass as? ResKnifePlugin.Type,
                let supportedTypes = plugin.infoDictionary?["RKEditedTypes"] as? Array<String>
            else {
                continue
            }
            SupportResourceRegistry.scanForResources(in: plugin)
            for type in supportedTypes {
                registry[type] = pluginClass
            }
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.makeFirstResponder(nil) // Ensure any controls have ended editing
        let plug = sender.windowController as! ResKnifePlugin
        if sender.isDocumentEdited && UserDefaults.standard.bool(forKey: kConfirmChanges) {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Do you want to keep the changes you made to this resource?", comment: "")
            alert.informativeText = NSLocalizedString("Your changes cannot be saved later if you don't keep them.", comment: "")
            alert.addButton(withTitle: NSLocalizedString("Keep", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Don't Keep", comment: ""))
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            alert.beginSheetModal(for: sender) { returnCode in
                switch (returnCode) {
                case .alertFirstButtonReturn: // keep
                    plug.saveResource?(alert)
                    sender.close()
                case .alertSecondButtonReturn: // don't keep
                    sender.close()
                default:
                    break
                }
            }
            return false
        }
        plug.saveResource?(sender)
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        let plug = (notification.object as! NSWindow).windowController as! ResKnifePlugin
        for (key, value) in editorWindows where value === plug {
            editorWindows.removeValue(forKey: key)
        }
    }
}
