import Cocoa

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var iconCache: [String: NSImage] = [:]
    // Don't configure prefs controller until needed
    private lazy var prefsController: NSWindowController = {
        ValueTransformer.setValueTransformer(LaunchActionTransformer(), forName: .launchActionTransformerName)
        let prefs = NSWindowController(windowNibName: "PrefsWindow")
        prefs.window?.center()
        return prefs
    }()
    
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
        
        SupportResourceRegistry.scanForResources()
        EditorRegistry.scanForPlugins()
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
        self.prefsController.showWindow(sender)
    }

    @IBAction func visitWebsite(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://resknife.sourceforge.net/")!)
    }
    
    @objc func icon(forResourceType resourceType: OSType) -> NSImage! {
        let type = GetNSStringFromOSType(resourceType)
        if iconCache[type] == nil, let editor = EditorRegistry.editor(for: type) {
            iconCache[type] = editor.icon?(forResourceType: resourceType)
        }
        if iconCache[type] == nil {
            iconCache[type] = NSWorkspace.shared.icon(forFileType: "")
        }
        return iconCache[type]
    }
}
