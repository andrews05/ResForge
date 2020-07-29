import Cocoa

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private static var iconCache: [String: NSImage] = [:]
    // Don't configure prefs controller until needed
    private lazy var prefsController: NSWindowController = {
        ValueTransformer.setValueTransformer(LaunchActionTransformer(), forName: .launchActionTransformerName)
        let prefs = NSWindowController(windowNibName: "PrefsWindow")
        prefs.window?.center()
        return prefs
    }()
    
    // Resource type to file type mapping, used for obtaining icons
    private static let typeMappings = [
        "cfrg": "shlb",
        "SIZE": "shlb",

        "CODE": "s",

        "STR ": "text",
        "STR#": "text",

        "plst": "plist",
        "url ": "webloc",

        //"hfdr": "com.apple.finder",

        "NFNT": "ttf",
        "sfnt": "ttf"
    ]
    
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
        
        SupportRegistry.scanForResources()
        PluginManager.scanForPlugins()
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
        InfoWindowController.shared.showWindow(sender)
    }
    
    @IBAction func showPrefs(_ sender: Any) {
        self.prefsController.showWindow(sender)
    }

    @IBAction func visitWebsite(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "http://resknife.sourceforge.net/")!)
    }
    
    @objc static func icon(for resourceType: String) -> NSImage! {
        if iconCache[resourceType] == nil, let editor = PluginManager.editor(for: resourceType) {
            // ask politly for icon
            iconCache[resourceType] = editor.icon?(for: resourceType)
        }
        if iconCache[resourceType] == nil {
            // try to retrieve from file system using our resource type to file name extension mapping, falling back to default document type
            iconCache[resourceType] = NSWorkspace.shared.icon(forFileType: Self.typeMappings[resourceType] ?? "")
        }
        return iconCache[resourceType]
    }
}
