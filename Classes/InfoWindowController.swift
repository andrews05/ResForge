import Foundation
import RKSupport

extension Notification.Name {
    static let DocumentInfoDidChange = Notification.Name("DocumentInfoDidChangeNotification")
}

// Extend the Resource class to add conflict checking when changing the type or id
extension Resource {
    func setType(_ type: String) -> Bool {
        if type != self.type {
            if self.hasConflict(type: type, id: self.id) {
                return false
            }
            self.type = type
        }
        return true
    }
    
    func setID(_ id: Int) -> Bool {
        if id != self.id {
            if self.hasConflict(type: self.type, id: id) {
                return false
            }
            self.id = id
        }
        return true
    }
    
    private func hasConflict(type: String, id: Int) -> Bool {
        // If changing id or type we need to check whether a matching resource already exists
        if (document as? ResourceDocument)?.dataSource()?.findResource(type: type, id: id) != nil {
            document?.presentError(ResourceError.conflict(type, id))
            return true
        }
        return false
    }
}

enum ResourceError: LocalizedError {
    case conflict(String, Int)
    var errorDescription: String? {
        switch self {
        case .conflict(let type, let id):
            return String(format: NSLocalizedString("A resource of type '%@' with ID %d already exists.", comment: ""), type, id)
        }
    }
    var recoverySuggestion: String? {
        switch self {
        case .conflict(_, _):
            return String(format: NSLocalizedString("Please enter a unique value.", comment: ""))
        }
    }
}

class InfoWindowController: NSWindowController {
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
        
        // set window to only accept key when editing text boxes
        (self.window as? NSPanel)?.becomesKeyOnlyIfNeeded = true
        self.setMainWindow(NSApp.mainWindow)
        self.update()
        
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowChanged(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedResourceChanged(_:)), name: NSOutlineView.selectionDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .ResourceDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .DocumentInfoDidChange, object: nil)
    }
    
    private func update() {
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
            
            creator.stringValue = document.creator.stringValue
            type.stringValue = document.type.stringValue
            
            // swap box
            placeholderView.contentView = documentView
        }
    }
    
    private func setMainWindow(_ mainWindow: NSWindow?) {
        if let document = mainWindow?.windowController?.document as? ResourceDocument {
            currentDocument = document
            selectedResource = document.outlineView().selectedItem as? Resource
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
    
    @IBAction func creatorChanged(_ sender: Any) {
        currentDocument.creator = OSType(creator.stringValue)
    }
    
    @IBAction func typeChanged(_ sender: Any) {
        currentDocument.type = OSType(type.stringValue)
    }
    
    @IBAction func nameChanged(_ sender: Any) {
        selectedResource.name = nameView.stringValue
    }
    
    @IBAction func rTypeChanged(_ sender: Any) {
        if !selectedResource.setType(rType.stringValue) {
            rType.stringValue = selectedResource.type // Change was rejected, reload
        }
    }
    
    @IBAction func rIDChanged(_ sender: Any) {
        if !selectedResource.setID(rID.integerValue) {
            rID.integerValue = selectedResource.id
        }
    }
    
    @IBAction func attributesChanged(_ sender: NSButton) {
        let att = ResAttributes(rawValue: sender.selectedTag())
        selectedResource.attributes.formSymmetricDifference(att)
    }
}
