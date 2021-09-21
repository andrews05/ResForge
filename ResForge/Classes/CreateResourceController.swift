import Cocoa
import RFSupport

class CreateResourceController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var createButton: NSButton!
    @IBOutlet var nameView: NSTextField!
    @IBOutlet var idView: NSTextField!
    @IBOutlet var typeView: NSComboBox!
    @IBOutlet var attributesHolder: NSView!
    @IBOutlet var attributesEditor: AttributesEditor!
    private unowned var rDocument: ResourceDocument
    private var currentType: ResourceType {
        ResourceType(typeView.stringValue, attributesEditor.attributes)
    }
    
    override var windowNibName: NSNib.Name? {
        "CreateResource"
    }
    
    init(_ document: ResourceDocument) {
        self.rDocument = document
        super.init(window: nil)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(type: ResourceType? = nil, id: Int? = nil, name: String? = nil) {
        _ = self.window
        // Add all types currently open
        let docs = NSDocumentController.shared.documents as! [ResourceDocument]
        var suggestions = Set(docs.flatMap { $0.directory.allTypes.map(\.code) })
        // Common types?
        suggestions.formUnion(["PICT", "snd ", "STR ", "STR#", "TMPL"])
        let sorted = suggestions.sorted {
            $0.localizedCompare($1) == .orderedAscending
        }
        typeView.removeAllItems()
        typeView.addItems(withObjectValues: sorted)
        if let formatter = idView.formatter as? NumberFormatter {
            formatter.minimum = rDocument.format.minID as NSNumber
            formatter.maximum = rDocument.format.maxID as NSNumber
        }
        
        typeView.objectValue = type?.code
        idView.objectValue = id
        nameView.objectValue = name
        if rDocument.format == .extended {
            attributesHolder.isHidden = false
            attributesEditor.attributes = type?.attributes ?? [:]
        } else {
            attributesHolder.isHidden = true
            attributesEditor.attributes = [:]
        }
        // The last non-nil value provided will receive focus
        if let type = type {
            if let id = id {
                idView.integerValue = rDocument.directory.uniqueID(for: type, starting: id)
                self.window?.makeFirstResponder(name == nil ? idView : nameView)
            } else {
                idView.integerValue = rDocument.directory.uniqueID(for: type)
                self.window?.makeFirstResponder(typeView)
            }
            createButton.isEnabled = true
        } else {
            self.window?.makeFirstResponder(typeView)
            createButton.isEnabled = false
        }
        rDocument.windowForSheet?.beginSheet(self.window!)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        createButton.isEnabled = false
        if obj.object as AnyObject === typeView {
            // If valid type, get a unique id
            if typeView.objectValue != nil {
                idView.integerValue = rDocument.directory.uniqueID(for: self.currentType)
                createButton.isEnabled = true
            }
        } else {
            // If valid type and id, check for conflict
            // Accessing the control value will force validation of the field, causing problems when trying to enter a negative id.
            // To workaround this, get the value from the field editor and manually run it through the formatter.
            if typeView.objectValue != nil, let value = (obj.userInfo?["NSFieldEditor"] as? NSText)?.string {
                if let id = try? idView.formatter!.getObjectValue(for: value) as? Int {
                    let resource = rDocument.directory.findResource(type: self.currentType, id: id)
                    createButton.isEnabled = resource == nil
                }
            }
        }
    }
    
    @IBAction func hide(_ sender: AnyObject) {
        if sender === createButton {
            let resource = Resource(type: self.currentType, id: idView.integerValue, name: nameView.stringValue)
            let actionName = NSLocalizedString("Create Resource", comment: "")
            rDocument.dataSource.reload(actionName: actionName) {
                rDocument.directory.add(resource)
                return [resource]
            }
            if !rDocument.dataSource.isBulkMode {
                rDocument.editorManager.open(resource: resource)
            }
        }
        self.window?.sheetParent?.endSheet(self.window!)
    }
}
