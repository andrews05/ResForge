import Cocoa

class SelectTemplateController: NSWindowController {
    @IBOutlet var typeList: NSComboBox!
    
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
        var templates = docs.flatMap {
            $0.collection.resources(ofType: "TMPL").map({ $0.name })
        }
        templates.append(contentsOf: SupportRegistry.collection.resources(ofType: "TMPL").map({ $0.name }))
        typeList.removeAllItems()
        typeList.addItems(withObjectValues: Array(Set(templates)).sorted())
        typeList.stringValue = type
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.window?.sheetParent?.endSheet(self.window!, returnCode: .cancel)
    }
    
    @IBAction func open(_ sender: Any) {
        self.window?.sheetParent?.endSheet(self.window!, returnCode: .OK)
    }
}
