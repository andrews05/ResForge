import Cocoa

class SelectTemplateController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var typeList: NSComboBox!
    @IBOutlet var openButton: NSButton!
    private var templates: Set<String>!
    
    override var windowNibName: NSNib.Name? {
        "SelectTemplate"
    }
    
    func show(_ document: ResourceDocument, type: String, complete: @escaping (String) -> Void) {
        document.windowForSheet?.beginSheet(self.window!) { modalResponse in
            if modalResponse == .OK {
                complete(self.typeList.stringValue)
            }
        }
        
        let docs = NSDocumentController.shared.documents as! [ResourceDocument]
        var names = docs.flatMap {
            $0.collection.resources(ofType: "TMPL").map({ $0.name })
        }
        names.append(contentsOf: SupportRegistry.collection.resources(ofType: "TMPL").map({ $0.name }))
        templates = Set(names)
        typeList.removeAllItems()
        typeList.addItems(withObjectValues: templates.sorted())
        if templates.contains(type) {
            typeList.stringValue = type
            openButton.isEnabled = true
        }
    }
    
    func controlTextDidChange(_ obj: Notification) {
        // The text must be one of the options in the list.
        // (A popup menu might seem more appropriate but we want the convenience of being able to type it in.)
        openButton.isEnabled = templates.contains(typeList.stringValue)
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.window?.sheetParent?.endSheet(self.window!, returnCode: .cancel)
    }
    
    @IBAction func open(_ sender: Any) {
        self.window?.sheetParent?.endSheet(self.window!, returnCode: .OK)
    }
}
