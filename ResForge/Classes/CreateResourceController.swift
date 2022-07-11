import Cocoa
import RFSupport

// The create resource implementation is designed around the following desired behaviours:
// 1. Create button should be disabled whenever the type or id is invalid, including while typing.
// 2. Most formatter errors should not be displayed but still prevent leaving the field.
// 3. A valid id should be generated whenever changing the type, or clearing the id field.
// 4. If an id is generated on pressing enter, this should not also create the resource as it may be confusing.

class CreateResourceController: NSWindowController, NSComboBoxDelegate {
    @IBOutlet var createButton: NSButton!
    @IBOutlet var nameView: NSTextField!
    @IBOutlet var idView: NSTextField!
    @IBOutlet var typeView: NSComboBox!
    @IBOutlet var attributesHolder: NSView!
    @IBOutlet var attributesEditor: AttributesEditor!
    private unowned var rDocument: ResourceDocument
    private var callback: ((Resource?) -> Void)?
    private var currentType: ResourceType {
        ResourceType(rType ?? "", attributesEditor.attributes)
    }
    
    // The type and id use bindings with continuous updates and formatters that always return a value.
    @objc dynamic private var rType: String? {
        didSet {
            // Generate an id when valid. We need to check the length as the formatter isn't enforcing a minimum.
            rID = rType?.count == 4 ? rDocument.directory.uniqueID(for: currentType) as NSNumber : nil
        }
    }
    @objc dynamic private var rID: NSNumber?
    @objc dynamic private var rName: String?
    
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
    
    func show(type: ResourceType? = nil, id: Int? = nil, name: String? = nil, callback: ((Resource?) -> Void)? = nil) {
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
        if rDocument.format == .extended {
            attributesHolder.isHidden = false
            attributesEditor.attributes = type?.attributes ?? [:]
        } else {
            attributesHolder.isHidden = true
            attributesEditor.attributes = [:]
        }

        rType = type?.code ?? rType
        if let type = type, let id = id {
            rID = rDocument.directory.uniqueID(for: type, starting: id) as NSNumber
        }
        rName = name
        // Focus the name field if a value is provided, otherwise the type field
        self.window?.makeFirstResponder(name == nil ? typeView : nameView)
        self.callback = callback
        rDocument.windowForSheet?.beginSheet(self.window!)
    }
    
    @IBAction func hide(_ sender: AnyObject) {
        if sender === createButton {
            // Safety check for invalid inputs (e.g. invalid MacRoman)
            guard window?.makeFirstResponder(nil) != false else {
                return
            }
            // Check for conflict
            let type = currentType
            let id = idView.integerValue
            if rDocument.directory.findResource(type: type, id: id) != nil {
                window?.presentError(ResourceError.conflict(type, id))
                return
            }
            // Create the resource
            let resource = Resource(type: type, id: id, name: nameView.stringValue)
            let actionName = NSLocalizedString("Create Resource", comment: "")
            rDocument.dataSource.reload(actionName: actionName) {
                rDocument.directory.add(resource)
                return [resource]
            }
            if !rDocument.dataSource.isBulkMode {
                rDocument.editorManager.open(resource: resource)
            }
            self.callback?(resource)
        } else {
            self.callback?(nil)
        }
        self.callback = nil
        self.window?.sheetParent?.endSheet(self.window!)
    }
    
    // Prevent leaving a field in an invalid state. The resID being nil should indicate this.
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if fieldEditor.string.isEmpty {
            // Trigger id generation
            rType = rType ?? nil
        }
        return rID != nil
    }
    
    // There's no way to know when the popup menu is open or not so we need to keep track of this manually.
    private var popupOpen = false
    func comboBoxWillPopUp(_ notification: Notification) {
        popupOpen = true
    }
    func comboBoxWillDismiss(_ notification: Notification) {
        popupOpen = false
    }
    
    // Detect enter key presses when the menu is open or the field is blank, which can cause a new id to be generated.
    // We want to trigger end of editing as normal but not create the resource.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) && (popupOpen || textView.string.isEmpty) {
            window?.makeFirstResponder(control)
            return true
        }
        return false
    }
}

/// A number formatter that always returns nil for invalid values rather than reporting errors.
class SilentNumberFormatter: NumberFormatter {
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        super.getObjectValue(obj, for: string, errorDescription: nil)
        return true
    }
}
