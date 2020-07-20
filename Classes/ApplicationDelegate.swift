import Cocoa

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var prefsController: NSWindowController?
    private var iconCache: [String: NSImage] = [:]
    @IBOutlet var openPanelDelegate: OpenPanelDelegate!
    
    override init() {
        NSApp.registerServicesMenuSendTypes([.string], returnTypes: [.string])
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let prefDict: [String: Any] = [
            kConfirmChanges: false,
            kDeleteResourceWarning: true,
            kLaunchAction: kDisplayOpenPanel
        ]
        UserDefaults.standard.register(defaults: prefDict)
        NSUserDefaultsController.shared.initialValues = prefDict
        
        RKSupportResourceRegistry.scanForSupportResources()
    }
    
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let launchAction = UserDefaults.standard.string(forKey: kLaunchAction)
        switch launchAction {
        case kOpenUntitledFile:
            return true
        case kDisplayOpenPanel:
            NSDocumentController.shared.openDocument(sender)
            return false
        default:
            return false
        }
    }
    
    @IBAction func showInfo(_ sender: Any) {
        InfoWindowController.shared().showWindow(sender)
    }
    
    @IBAction func showPrefs(_ sender: Any) {
        if self.prefsController == nil {
            ValueTransformer.setValueTransformer(LaunchActionTransformer(), forName: .launchActionTransformerName)
            self.prefsController = NSWindowController(windowNibName: "PrefsWindow")
        }
        self.prefsController?.showWindow(sender)
        self.prefsController?.window?.makeKeyAndOrderFront(sender)
    }

    @IBAction func visitWebsite(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://resknife.sourceforge.net/")!)
    }
    
    @objc public func icon(forResourceType resourceType: OSType) -> NSImage! {
        let type = GetNSStringFromOSType(resourceType)
        var icon = iconCache[type]
        if icon == nil {
            icon = NSWorkspace.shared.icon(forFileType: "")
            iconCache[type] = icon
        }
        return icon
    }
}
