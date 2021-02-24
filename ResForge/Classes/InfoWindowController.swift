import Cocoa
import RFSupport

class InfoWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    @IBOutlet var placeholderView: NSView!
    @IBOutlet var resourceView: NSView!
    @IBOutlet var documentView: NSView!
    
    @IBOutlet var iconView: NSImageView!
    @IBOutlet var nameView: NSTextField!
    @IBOutlet var creator: NSTextField!
    @IBOutlet var type: NSTextField!
    @IBOutlet var dataSize: NSTextField!
    @IBOutlet var rsrcSize: NSTextField!
    
    @IBOutlet var rName: NSTextField!
    @IBOutlet var rType: NSTextField!
    @IBOutlet var rID: NSTextField!
    @IBOutlet var rSize: NSTextField!
    @IBOutlet var attributesMatrix: NSMatrix!
    
    private weak var currentDocument: ResourceDocument?
    private weak var selectedResource: Resource?
    
    static var shared = InfoWindowController(windowNibName: "InfoWindow")
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.setMainWindow(NSApp.mainWindow)
        
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowChanged(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowResigned(_:)), name: NSWindow.didResignMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedResourceChanged(_:)), name: .DocumentSelectionDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .ResourceDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .DocumentInfoDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .DocumentInfoDidChange, object: nil)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Cancel all editing on close (not sure how to just get the active field)
        creator.abortEditing()
        type.abortEditing()
        rName.abortEditing()
        rType.abortEditing()
        rID.abortEditing()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // End editing (accept changes) when clicking out of the window
        self.window?.makeFirstResponder(nil)
    }
    
    private func update() {
        if let resource = selectedResource {
            // set UI values
            self.window?.title = NSLocalizedString("Resource Info", comment: "")
            rName.stringValue = resource.name
            rType.stringValue = resource.type
            rID.integerValue = resource.id
            rSize.integerValue = resource.data.count
            
            attributesMatrix.cell(withTag: ResAttributes.changed.rawValue)?.state    = resource.attributes.contains(.changed) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.preload.rawValue)?.state    = resource.attributes.contains(.preload) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.protected.rawValue)?.state  = resource.attributes.contains(.protected) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.locked.rawValue)?.state     = resource.attributes.contains(.locked) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.purgeable.rawValue)?.state  = resource.attributes.contains(.purgeable) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.sysHeap.rawValue)?.state    = resource.attributes.contains(.sysHeap) ? .on : .off
            
            // swap view
            self.window?.contentView = resourceView
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
            
            // swap view
            self.window?.contentView = documentView
        } else {
            self.window?.title = NSLocalizedString("Document Info", comment: "")
            self.window?.contentView = placeholderView
        }
    }
    
    private func setMainWindow(_ mainWindow: NSWindow?) {
        if let document = mainWindow?.windowController?.document as? ResourceDocument {
            currentDocument = document
            selectedResource = document.dataSource.selectionCount() == 1 ? document.dataSource.selectedResources().first : nil
        } else {
            currentDocument = nil
            selectedResource = (mainWindow?.windowController as? ResourceEditor)?.resource
        }
        self.update()
    }
    
    @objc func mainWindowChanged(_ notification: Notification) {
        self.setMainWindow(notification.object as? NSWindow)
    }
    
    @objc func mainWindowResigned(_ notification: Notification) {
        if (notification.object as? NSWindow)?.windowController?.document === currentDocument {
            currentDocument = nil
            selectedResource = nil
            self.update()
        }
    }
    
    @objc func selectedResourceChanged(_ notification: Notification) {
        if let document = currentDocument, notification.object as AnyObject? === document {
            let resource = document.dataSource.selectionCount() == 1 ? document.dataSource.selectedResources().first : nil
            if resource !== selectedResource {
                selectedResource = resource
                self.update()
            }
        }
    }

    @objc func propertiesChanged(_ notification: Notification) {
        self.update()
    }
    
    // Check for conflicts
    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        let textField = control as! NSTextField
        switch textField.identifier?.rawValue {
        case "rType":
            return selectedResource?.canSetType(obj as! String) ?? false
        case "rID":
            return selectedResource?.canSetID(obj as! Int) ?? false
        default:
            break
        }
        return true
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        let textField = obj.object as! NSTextField
        switch textField.identifier?.rawValue {
        case "name":
            selectedResource?.name = textField.stringValue
        case "rType":
            selectedResource?.type = textField.stringValue
        case "rID":
            selectedResource?.id = textField.integerValue
        case "creator":
            currentDocument?.hfsCreator = OSType(textField.stringValue)
        case "type":
            currentDocument?.hfsType = OSType(textField.stringValue)
        default:
            break
        }
    }
    
    @IBAction func attributesChanged(_ sender: NSButton) {
        let att = ResAttributes(rawValue: sender.selectedTag())
        selectedResource?.attributes.formSymmetricDifference(att)
    }
}
