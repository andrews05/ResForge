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
    @IBOutlet var typeAttsHolder: NSView!
    @IBOutlet var rTypeAtts: AttributesEditor!

    @IBOutlet var objectController: NSObjectController!

    static var shared = InfoWindowController(windowNibName: "InfoWindow")

    override func windowWillLoad() {
        ValueTransformer.setValueTransformer(FourCharCodeTransformer(), forName: .fourCharCodeTransformerName)
    }

    override func windowDidLoad() {
        self.setMainWindow(NSApp.mainWindow)

        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowChanged(_:)), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(mainWindowResigned(_:)), name: NSWindow.didResignMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectedResourceChanged(_:)), name: .DocumentSelectionDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .ResourceDataDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(propertiesChanged(_:)), name: .DocumentInfoDidChange, object: nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        window?.makeFirstResponder(window)
    }

    func windowWillClose(_ notification: Notification) {
        // Suppress all errors when closing
        try? objectController.commitEditingWithoutPresentingError()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        self.refresh()
        window?.makeFirstResponder(window?.initialFirstResponder)
    }

    private func refresh() {
        guard self.window?.isVisible == true else {
            return
        }
        if let resource = objectController.content as? Resource {
            window?.title = NSLocalizedString("Resource Info", comment: "")

            rSize.integerValue = resource.data.count
            typeAttsHolder.isHidden = (resource.document as? ResourceDocument)?.format != .extended
            rTypeAtts.attributes = resource.typeAttributes

            window?.contentView = resourceView
            window?.initialFirstResponder = rName
        } else if let document = objectController.content as? ResourceDocument {
            window?.title = NSLocalizedString("Document Info", comment: "")

            dataSize.integerValue = 0
            rsrcSize.integerValue = 0

            if let url = document.fileURL {
                iconView.image = NSWorkspace.shared.icon(forFile: url.path)
                nameView.stringValue = url.lastPathComponent
                // Read fork sizes
                do {
                    let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
                    dataSize.integerValue = values.fileSize!
                    rsrcSize.integerValue = values.totalFileSize! - values.fileSize!
                } catch {}
            } else {
                iconView.image = NSWorkspace.shared.icon(forFileType: "com.resforge.resource-file")
                nameView.stringValue = document.displayName
            }

            window?.contentView = documentView
            window?.initialFirstResponder = type
        } else {
            window?.title = NSLocalizedString("Document Info", comment: "")
            window?.contentView = placeholderView
        }
    }

    private func setMainWindow(_ mainWindow: NSWindow?) {
        if let document = mainWindow?.windowController?.document as? ResourceDocument {
            objectController.content = self.object(for: document)
        } else {
            objectController.content = (mainWindow?.windowController as? ResourceEditor)?.resource
        }
        self.refresh()
    }

    private func object(for document: ResourceDocument) -> AnyObject {
        if document.dataSource.selectionCount() == 1 {
            return document.dataSource.selectedResources().first ?? document
        }
        return document
    }

    @objc func mainWindowChanged(_ notification: Notification) {
        self.setMainWindow(notification.object as? NSWindow)
    }

    @objc func mainWindowResigned(_ notification: Notification) {
        if NSApp.mainWindow == nil {
            objectController.content = nil
            self.refresh()
        }
    }

    @objc func selectedResourceChanged(_ notification: Notification) {
        if let document = notification.object as? ResourceDocument, document === NSApp.mainWindow?.windowController?.document {
            let object = self.object(for: document)
            if object !== objectController.content as AnyObject {
                objectController.content = object
                self.refresh()
            }
        }
    }

    @objc func propertiesChanged(_ notification: Notification) {
        self.refresh()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        // Discard editing on escape - this would otherwise close the window immediately
        switch commandSelector {
        case #selector(cancelOperation(_:)):
            objectController.discardEditing()
            return true
        default:
            return false
        }
    }

    func control(_ control: NSControl, didFailToFormatString string: String, errorDescription error: String?) -> Bool {
        // Suppress formatter errors
        try? objectController.commitEditingWithoutPresentingError()
        return true
    }

    @IBAction func applyAttributes(_ sender: NSButton) {
        // Make sure the type/id fields are committed before saving attributes
        if window?.makeFirstResponder(nil) != false, let resource = objectController.content as? Resource {
            do {
                let attributes = rTypeAtts.attributes
                try resource.checkConflict(typeAttributes: attributes)
                resource.typeAttributes = attributes
                rTypeAtts.attributes = attributes
            } catch let error {
                window?.presentError(error)
            }
        }
    }
}

class FourCharCodeTransformer: ValueTransformer {
    override func transformedValue(_ value: Any?) -> Any? {
        return (value as! FourCharCode).stringValue
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let value = value as? String {
            return FourCharCode(value)
        }
        return 0
    }

    override class func allowsReverseTransformation() -> Bool {
        true
    }
}

extension NSValueTransformerName {
    static let fourCharCodeTransformerName = Self("FourCharCodeTransformer")
}

// These extensions allow the outline and collection views to change selection with a single click while the info window is key.
// This makes it easier for the user to update multiple resources consecutively.
extension NSOutlineView {
    open override var needsPanelToBecomeKey: Bool {
        return !(window?.isMainWindow == true && window?.isKeyWindow == false)
    }
}
extension NSImageView {
    open override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}
