import Cocoa

/// The abstract editor provides some default functionality for save handling. Do not extend this without also conforming to ResourceEditor.
open class AbstractEditor: NSWindowController, NSWindowDelegate, NSMenuItemValidation {
    open override func loadWindow() {
        super.loadWindow()
        guard let window, let plug = window.windowController as? ResourceEditor else {
            return
        }
        // Use a short title for the title bar but include the document name in the Window menu
        window.title = plug.resource.defaultWindowTitle
        if let docName = plug.resource.document?.displayName {
            NSApp.changeWindowsItem(window, title: "\(docName): \(window.title)", filename: false)
        }
    }

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
        self.exportResource(using: type(of: self) as? ExportProvider.Type)
    }

    @IBAction func exportRawResource(_ sender: Any) {
        self.exportResource(using: nil)
    }

    private func exportResource(using exporter: ExportProvider.Type?) {
        guard let resource = (self as? ResourceEditor)?.resource else {
            return
        }
        let panel = NSSavePanel()
        let filename = resource.filenameForExport(using: exporter)
        panel.nameFieldStringValue = "\(filename.name).\(filename.ext)"
        panel.isExtensionHidden = false
        if exporter != nil {
            panel.allowedFileTypes = [filename.ext]
        }
        panel.beginSheetModal(for: self.window!) { returnCode in
            if returnCode == .OK, let url = panel.url {
                do {
                    if !resource.data.isEmpty, let exporter {
                        try exporter.export(resource, to: url)
                    } else {
                        try resource.data.write(to: url)
                    }
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
        case "exportResource":
            return self is ExportProvider
        default:
            return true
        }
    }
}
