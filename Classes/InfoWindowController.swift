import Foundation
import ResKnifePlugins

extension Notification.Name {
    static let DocumentInfoWillChange = Notification.Name("DocumentInfoWillChangeNotification")
    static let DocumentInfoDidChange = Notification.Name("DocumentInfoDidChangeNotification")
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
    
    private var currentDocument: ResourceDocument?
    private var selectedResource: Resource?
    
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
            
            attributesMatrix.cell(withTag: ResAttributes.resChanged.rawValue)?.state    = resource.attributes.contains(.resChanged) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.resPreload.rawValue)?.state    = resource.attributes.contains(.resPreload) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.resProtected.rawValue)?.state  = resource.attributes.contains(.resProtected) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.resLocked.rawValue)?.state     = resource.attributes.contains(.resLocked) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.resPurgeable.rawValue)?.state  = resource.attributes.contains(.resPurgeable) ? .on : .off
            attributesMatrix.cell(withTag: ResAttributes.resSysHeap.rawValue)?.state    = resource.attributes.contains(.resSysHeap) ? .on : .off
            
            rType.stringValue = resource.type
            rID.integerValue = resource.resID
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
            selectedResource = (mainWindow?.windowController as? ResKnifePlugin)?.resource as? Resource
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
        currentDocument?.creator = OSType(creator.stringValue)
    }
    
    @IBAction func typeChanged(_ sender: Any) {
        currentDocument?.type = OSType(type.stringValue)
    }
    
    @IBAction func nameChanged(_ sender: Any) {
        selectedResource?.name = nameView.stringValue
    }
    
    @IBAction func rTypeChanged(_ sender: Any) {
        selectedResource!.type = rType.stringValue
        rType.stringValue = selectedResource!.type // Reload in case change was rejected
    }
    
    @IBAction func rIDChanged(_ sender: Any) {
        selectedResource!.resID = rID.integerValue
        rID.integerValue = selectedResource!.resID
    }
    
    @IBAction func attributesChanged(_ sender: NSButton) {
        let att = ResAttributes(rawValue: sender.selectedTag())
        selectedResource!.attributes.formSymmetricDifference(att)
    }
}
