import Cocoa
import RFSupport

class SelectTemplateController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var typeList: NSComboBox!
    @IBOutlet var openButton: NSButton!
    private var templates: Set<String>!
    
    override var windowNibName: NSNib.Name? {
        "SelectTemplate"
    }
    
    func show(_ document: ResourceDocument, typeCode: String, complete: @escaping (String) -> Void) {
        _ = self.window
        let docs = NSDocumentController.shared.documents as! [ResourceDocument]
        var names = docs.flatMap {
            $0.directory.resources(ofType: PluginRegistry.templateType).map({ $0.name })
        }
        names.append(contentsOf: SupportRegistry.directory.resources(ofType: PluginRegistry.templateType).map({ $0.name }))
        templates = Set(names) // Remove any duplicates
        typeList.addItems(withObjectValues: templates.sorted())
        
        if templates.contains(typeCode) {
            typeList.stringValue = typeCode
            openButton.isEnabled = true
        }
        document.windowForSheet?.beginSheet(self.window!) { modalResponse in
            if modalResponse == .OK {
                complete(self.typeList.stringValue)
            }
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        // The text must be one of the options in the list.
        // (A popup menu might seem more appropriate but we want the convenience of being able to type it in.)
        openButton.isEnabled = templates.contains(typeList.stringValue)
    }
    
    @IBAction func hide(_ sender: AnyObject) {
        self.window?.sheetParent?.endSheet(self.window!, returnCode: sender === openButton ? .OK : .cancel)
    }
}
