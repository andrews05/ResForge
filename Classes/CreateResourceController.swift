import Cocoa
import RKSupport

class CreateResourceController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var createButton: NSButton!
    @IBOutlet var nameView: NSTextField!
    @IBOutlet var idView: NSTextField!
    @IBOutlet var typeView: NSComboBox!
    var collection: ResourceCollection!
    
    override var windowNibName: NSNib.Name? {
        "CreateResourceSheet"
    }
    
    func showSheet(in document: ResourceDocument, type: String? = nil, id: Int = 128) {
        _ = self.window
        collection = document.collection
        // Add all types currently in the document
        var suggestions = collection.allTypes
        // Common types?
        for value in ["BNDL", "vers", "STR ", "STR#", "TEXT"] {
            if !suggestions.contains(value) {
                suggestions.append(value)
            }
        }
        typeView.removeAllItems()
        typeView.addItems(withObjectValues: suggestions)
        
        if let type = type {
            typeView.stringValue = type
            idView.integerValue = collection.uniqueID(for: type, starting: id)
            createButton.isEnabled = true
        } else if typeView.stringValue.count == 4 {
            idView.integerValue = collection.uniqueID(for: typeView.stringValue, starting: idView.integerValue)
            createButton.isEnabled = true
        } else {
            createButton.isEnabled = false
        }
        document.windowForSheet?.beginSheet(self.window!, completionHandler: nil)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        // Accessing the control value will force validation of the field, causing problems when trying to enter a negative id.
        // To workaround this, check the field editor for a negative symbol before checking the id value.
        if typeView.objectValue == nil || (obj.userInfo!["NSFieldEditor"] as! NSText).string == "-" || idView.objectValue == nil {
            createButton.isEnabled = false
        } else {
            // Check for conflict
            let resource = collection.findResource(type: typeView.stringValue, id: idView.integerValue)
            createButton.isEnabled = resource == nil
        }
    }
    
    @IBAction func typeChanged(_ sender: Any) {
        // Get a suitable id for this type
        idView.integerValue = collection.uniqueID(for: typeView.stringValue)
        createButton.isEnabled = true
    }
    
    @IBAction func hide(_ sender: AnyObject) {
        if sender === createButton {
            let resource = Resource(type: typeView.stringValue, id: idView.integerValue, name: nameView.stringValue)
            collection.document.dataSource.reload {
                [collection.add(resource)]
            }
            collection.document.undoManager?.setActionName(NSLocalizedString("Create Resource", comment: ""))
            collection.document.pluginManager.open(resource: resource)
        }
        self.window?.sheetParent?.endSheet(self.window!)
    }
}
