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

        "cicn": "icns",
        "SICN": "icns",
        "icl8": "icns",
        "icl4": "icns",
        "ICON": "icns",
        "ICN#": "icns",
        "ics8": "icns",
        "ics4": "icns",
        "ics#": "icns",
        "icm8": "icns",
        "icm4": "icns",
        "icm#": "icns",

        "PNG ": "png",

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
            iconCache[type] = NSWorkspace.shared.icon(forFileType: Self.typeMappings[type] ?? "")
        }
        return iconCache[type]
    }
}
