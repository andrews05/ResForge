import Foundation

class CreateResourceController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var createButton: NSButton!
    @IBOutlet var nameView: NSTextField!
    @IBOutlet var idView: NSTextField!
    @IBOutlet var typeView: NSComboBox!
    
    var dataSource: ResourceDataSource!
    
    @objc func showSheet(in document: ResourceDocument, type: String! = nil) {
        self.loadWindow()
        dataSource = document.dataSource()
        // Add all types currently in the document
        var suggestions = dataSource.allTypes as! [String]
        // Common types?
        for value in ["BNDL", "vers", "STR ", "STR#", "TEXT"] {
            if !suggestions.contains(value) {
                suggestions.append(value)
            }
        }
        typeView.removeAllItems()
        typeView.addItems(withObjectValues: suggestions)
        
        if type != nil {
            typeView.stringValue = type
//            if id != nil {
//                idView.integerValue = id
//                let resource = document.dataSource()?.resource(ofType: GetOSTypeFromNSString(type), andID: Int16(id))
//                createButton.isEnabled = resource == nil
//            } else {
                self.typeChanged(self)
//            }
        }
        document.windowForSheet?.beginSheet(self.window!, completionHandler: nil)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if typeView.stringValue.count != 4 || idView.stringValue.count == 0 {
            createButton.isEnabled = false
        } else {
            // Check for conflict
            let resource = dataSource.resource(ofType: GetOSTypeFromNSString(typeView.stringValue), andID: Int16(idView.integerValue))
            createButton.isEnabled = resource == nil
        }
    }
    
    @IBAction func typeChanged(_ sender: Any) {
        // Get a suitable id for this type
        idView.integerValue = Int(dataSource.uniqueID(forType: GetOSTypeFromNSString(typeView.stringValue)))
        createButton.isEnabled = true
    }
    
    @IBAction func hide(_ sender: Any) {
        if sender as AnyObject === createButton {
            let resource = Resource(ofType: GetOSTypeFromNSString(typeView.stringValue),
                                    andID: Int16(idView.integerValue),
                                    withName: nameView.stringValue,
                                    andAttributes: 0)!
            dataSource.document.undoManager?.beginUndoGrouping()
            dataSource.addResource(resource)
            var actionName = NSLocalizedString("Create Resource", comment: "")
            if nameView.stringValue.count > 0 {
                actionName = actionName.appending(" '\(nameView.stringValue)'")
            }
            dataSource.document.undoManager?.setActionName(actionName)
            dataSource.document.undoManager?.endUndoGrouping()
            resource.open()
        }
        self.window?.sheetParent?.endSheet(self.window!)
    }
}
