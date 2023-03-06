import Cocoa

/// The abstract editor provides some default functionality for save handling. Do not extend this without also conforming to ResourceEditor.
open class AbstractEditor: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Ensure any controls have ended editing
        if !sender.makeFirstResponder(nil) {
            return false
        }
        if sender.isDocumentEdited, let plug = sender.windowController as? ResourceEditor {
            if UserDefaults.standard.bool(forKey: "ConfirmChanges") {
                let alert = NSAlert()
                alert.messageText = NSLocalizedString("Do you want to save the changes you made to this resource?", comment: "")
                alert.addButton(withTitle: NSLocalizedString("Save Changes", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Discard", comment: ""))
                alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
                alert.beginSheetModal(for: sender) { returnCode in
                    switch returnCode {
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
    
    @IBAction func saveDocument(_ sender: Any) {
        // Ensure any controls have ended editing, then save both the resource and the document
        if let editor = self as? ResourceEditor, editor.window?.makeFirstResponder(nil) != false {
            editor.saveResource(sender)
            editor.resource.document?.save(sender)
        }
    }
    
    @IBAction func exportResource(_ sender: Any) {
        guard let plug = self as? ResourceEditor,
              let exporter = type(of: self) as? ExportProvider.Type else {
            return
        }
        let resource = plug.resource
        let panel = NSSavePanel()
        if resource.name.isEmpty {
            panel.nameFieldStringValue = "\(resource.typeCode) \(resource.id)"
        } else {
            panel.nameFieldStringValue = resource.name
        }
        panel.allowedFileTypes = [exporter.filenameExtension(for: resource.typeCode)]
        panel.beginSheetModal(for: self.window!) { returnCode in
            if returnCode == .OK {
                do {
                    try exporter.export(plug.resource, to: panel.url!)
                } catch {
                    self.presentError(error)
                }
            }
        }
    }
    
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.identifier?.rawValue {
        case "revertResource":
            menuItem.title = NSLocalizedString("Revert Resource", comment: "")
            fallthrough
        case "saveResource", "save":
            return self.window?.isDocumentEdited == true
        case "exportResources":
            return self is ExportProvider
        default:
            return true
        }
    }
}
