import Cocoa
import RKSupport

class InfoWindowController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var iconView: NSImageView!
    @IBOutlet var nameView: NSTextField!
    @IBOutlet var placeholderView: NSBox!
    @IBOutlet var resourceView: NSBox!
    @IBOutlet var documentView: NSBox!
    
    @IBOutlet var creator: NSTextField!
    @IBOutlet var type: NSTextField!
    @IBOutlet var dataSize: NSTextField!
    @IBOutlet var rsrcSize: NSTextField!
    
    @IBOutlet var rType: NSTextField!
    @IBOutlet var rID: NSTextField!
    @IBOutlet var rSize: NSTextField!
    @IBOutlet var attributesMatrix: NSMatrix!
    
    private var currentDocument: ResourceDocument!
    private var selectedResource: Resource!
    
    static var shared = InfoWindowController(windowNibName: "InfoWindow")
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        self.setMainWindow(NSApp.mainWindow)
        self.update()
        
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowChanged(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedResourceChanged(_:)), name: NSOutlineView.selectionDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .ResourceDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .DocumentInfoDidChange, object: nil)
    }
    
    private func update() {
        nameView.abortEditing()
        nameView.isEditable = selectedResource != nil
        nameView.isBezeled = selectedResource != nil
        
        if let resource = selectedResource {
            // set UI values
            self.window?.title = NSLocalizedString("Resource Info", comment: "")
            nameView.stringValue = resource.name
            iconView.image = ApplicationDelegate.icon(for: resource.type)
            
            attributesMatrix.cell(withTag: ResAttributes.changed.rawValue)?.state    = resource.attributes.contains(.changed) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.preload.rawValue)?.state    = resource.attributes.contains(.preload) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.protected.rawValue)?.state  = resource.attributes.contains(.protected) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.locked.rawValue)?.state     = resource.attributes.contains(.locked) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.purgeable.rawValue)?.state  = resource.attributes.contains(.purgeable) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.sysHeap.rawValue)?.state    = resource.attributes.contains(.sysHeap) ? .on : .off
            
            rType.stringValue = resource.type
            rID.integerValue = resource.id
            rSize.integerValue = resource.data.count
            
            // swap box
            placeholderView.contentView = resourceView
        } else if let document = currentDocument {
            // get sizes of forks as they are on disk
            dataSize.integerValue = 0
            rsrcSize.integerValue = 0
            
            // set info window elements to correct values
            self.window?.title = NSLocalizedString("Document Info", comment: "")
            if let url = document.fileURL {
                iconView.image = NSWorkspace.shared.icon(forFile: url.path)
                nameView.stringValue = url.lastPathComponent
                do {
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
                    dataSize.integerValue = values.fileSize!
                    rsrcSize.integerValue = values.totalFileSize! - values.fileSize!
                } catch {}
            } else {
                iconView.image = NSImage(named: "Resource file")
                nameView.stringValue = document.displayName
            }
            
            creator.stringValue = document.hfsCreator.stringValue
            type.stringValue = document.hfsType.stringValue
            
            // swap box
            placeholderView.contentView = documentView
        }
    }
    
    private func setMainWindow(_ mainWindow: NSWindow?) {
        if let document = mainWindow?.windowController?.document as? ResourceDocument {
            currentDocument = document
            selectedResource = document.outlineView.selectedItem as? Resource
        } else {
            currentDocument = nil
            selectedResource = (mainWindow?.windowController as? ResKnifePlugin)?.resource
        }
        self.update()
    }
    
    @objc func mainWindowChanged(_ notification: Notification) {
        self.setMainWindow(notification.object as? NSWindow)
    }
    
    @objc func selectedResourceChanged(_ notification: Notification) {
        let outline = notification.object as! NSOutlineView
        if outline.window?.windowController?.document === currentDocument {
            selectedResource = outline.selectedItem as? Resource
            self.update()
        }
    }

    @objc func propertiesChanged(_ notification: Notification) {
        self.update()
    }
    
    // Check for conflicts
    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        guard selectedResource != nil else {
            return false
        }
        let textField = control as! NSTextField
        switch textField.identifier?.rawValue {
        case "rType":
            return selectedResource.canSetType(obj as! String)
        case "rID":
            return selectedResource.canSetID(obj as! Int)
        default:
            break
        }
        return true
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        guard selectedResource != nil else {
            return
        }
        let textField = obj.object as! NSTextField
        switch textField.identifier?.rawValue {
        case "name":
            selectedResource.name = textField.stringValue
        case "rType":
            selectedResource.type = textField.stringValue
        case "rID":
            selectedResource.id = textField.integerValue
        case "creator":
            currentDocument.hfsCreator = OSType(textField.stringValue)
        case "type":
            currentDocument.hfsType = OSType(textField.stringValue)
        default:
            break
        }
    }
    
    @IBAction func attributesChanged(_ sender: NSButton) {
        let att = ResAttributes(rawValue: sender.selectedTag())
        selectedResource.attributes.formSymmetricDifference(att)
    }
}
