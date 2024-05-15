import AppKit
import RFSupport

enum OpenTemplateError: LocalizedError {
    case noTemplate
    var errorDescription: String? {
        switch self {
        case .noTemplate:
            return NSLocalizedString("Please select a template.", comment: "")
        }
    }
}

/// Document that allows editing a file directly in a template.
class TemplateDocument: NSDocument {
    private var editor: TemplateEditor!

    override func read(from data: Data, ofType typeName: String) throws {
        if editor == nil {
            guard let template = OpenTemplateDelegate.getSelectedTemplate() else {
                throw OpenTemplateError.noTemplate
            }
            let resource = Resource(type: ResourceType(typeName), id: 0, data: data)
            editor = TemplateDocumentEditor(resource: resource, manager: EditorManager.shared, template: template, filter: nil)
            guard editor != nil else {
                throw CocoaError(.fileReadUnknown)
            }
            self.addWindowController(editor)
            editor.window?.delegate = editor
            editor.showWindow(self)
        } else {
            editor.load(data: data)
        }
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        // Ensure any controls have ended editing
        if editor.window?.makeFirstResponder(nil) != false {
            super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        editor.getData()
    }

    override func save(_ sender: Any?) {
        super.save(sender)
        NotificationCenter.default.post(name: .DocumentInfoDidChange, object: self)
    }
}

// Override some functions of the template editor to suit the document model
class TemplateDocumentEditor: TemplateEditor {
    override func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Keep the usual resource menu items disabled
        switch menuItem.identifier?.rawValue {
        case "saveResource", "revertResource", "exportResource":
            return false
        case "save":
            return document?.isDocumentEdited == true
        default:
            return true
        }
    }

    override func itemValueUpdated(_ sender: Any) {
        document?.updateChangeCount(.changeDone)
    }

    override func saveDocument(_ sender: Any) {
        (document as? NSDocument)?.save(sender)
    }
}

class OpenTemplateDelegate: NSObject, NSOpenSavePanelDelegate {
    @IBOutlet var accessoryView: NSView!
    @IBOutlet var templateSelect: NSComboBox!
    private var templates: [String: Resource] = [:]
    private(set) static var selectedTemplate: Resource?

    static func getSelectedTemplate() -> Resource? {
        defer {
            selectedTemplate = nil
        }
        return selectedTemplate
    }

    func panelSelectionDidChange(_ sender: Any?) {
        guard let ext = (sender as! NSOpenPanel).url?.pathExtension.lowercased(), !ext.isEmpty else {
            return
        }
        // First try to find a dedicated template for the extension, then try a more loose match
        let match = templateSelect.objectValues.first { value in
            ".\(ext)" == value as? String
        } ?? templateSelect.objectValues.first { value in
            ext == (value as? String)?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let match {
            templateSelect.objectValue = match
        }
    }

    func panel(_ sender: Any, validate url: URL) throws {
        if templates[templateSelect.stringValue] == nil {
            throw OpenTemplateError.noTemplate
        }
    }

    @IBAction func begin(_ sender: Any?) {
        // Populate the template list
        let allTemplates = EditorManager.shared.allResources(ofType: ResourceType.Template)
        for template in allTemplates {
            if templates[template.name] == nil {
                templates[template.name] = template
            }
        }
        let sorted = templates.keys.sorted {
            $0.localizedCompare($1) == .orderedAscending
        }
        templateSelect.addItems(withObjectValues: sorted)

        // Prepare and show the panel
        let openPanel = NSOpenPanel()
        openPanel.delegate = self
        openPanel.accessoryView = accessoryView
        openPanel.isAccessoryViewDisclosed = true
        openPanel.begin { [self] modalResponse in
            defer {
                templates = [:]
                templateSelect.removeAllItems()
            }
            guard modalResponse == .OK,
                  let url = openPanel.url,
                  let template = templates[templateSelect.stringValue]
            else {
                return
            }
            Self.selectedTemplate = template
            if let doc = try? TemplateDocument(contentsOf: url, ofType: template.name) {
                NSDocumentController.shared.addDocument(doc)
            }
        }
    }
}
