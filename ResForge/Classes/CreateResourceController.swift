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
        idView.formatter = rDocument.idFormatter
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(type: ResourceType? = nil, id: Int? = nil, name: String? = nil) {
        _ = self.window
        // Add all types currently in the document
        var suggestions = rDocument.directory.allTypes.map { $0.code }
        // Common types?
        for value in ["PICT", "snd ", "STR ", "STR#", "TMPL", "vers"] {
            if !suggestions.contains(value) {
                suggestions.append(value)
            }
        }
        typeView.removeAllItems()
        typeView.addItems(withObjectValues: suggestions)
        
        var type = type
        typeView.objectValue = type?.code
        idView.objectValue = id
        nameView.objectValue = name
        if rDocument.format == .extended {
            attributesHolder.isHidden = false
        } else {
            attributesHolder.isHidden = true
            type?.attributes = [:]
        }
        // The last non-nil value provided will receive focus
        if let type = type {
            attributesEditor.attributes = type.attributes
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
            // To workaround this, check the field editor for a negative symbol before checking the value.
            if typeView.objectValue != nil && (obj.userInfo!["NSFieldEditor"] as! NSText).string != "-" && idView.objectValue != nil {
                let resource = rDocument.directory.findResource(type: self.currentType, id: idView.integerValue)
                createButton.isEnabled = resource == nil
            }
        }
    }
    
    @IBAction func hide(_ sender: AnyObject) {
        if sender === createButton {
            let resource = Resource(type: self.currentType, id: idView.integerValue, name: nameView.stringValue)
            rDocument.dataSource.reload {
                rDocument.directory.add(resource)
                return [resource]
            }
            rDocument.undoManager?.setActionName(NSLocalizedString("Create Resource", comment: ""))
            rDocument.editorManager.open(resource: resource)
        }
        self.window?.sheetParent?.endSheet(self.window!)
    }
}
