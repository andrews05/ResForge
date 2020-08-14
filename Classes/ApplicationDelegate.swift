import Cocoa
import RKSupport

@NSApplicationMain
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
            kLaunchAction: kDisplayOpenPanel,
            kShowSidebar: false
        ]
        UserDefaults.standard.register(defaults: prefDict)
        
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
    
    /// Returns an icon representing the resource type.
    static func icon(for resourceType: String) -> NSImage! {
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
    
    /// Returns a placeholder name to show for a resource when it has no name.
    static func placeholderName(for resource: Resource) -> String {
        if resource.id == -16455 {
            // don't bother checking type since there are too many icon types
            return NSLocalizedString("Custom Icon", comment: "")
        }
        
        switch resource.type {
        case "carb":
            if resource.id == 0 {
                return NSLocalizedString("Carbon Identifier", comment: "")
            }
        case "pnot":
            if resource.id == 0 {
                return NSLocalizedString("File Preview", comment: "")
            }
        case "STR ":
            if resource.id == -16396 {
                return NSLocalizedString("Creator Information", comment: "")
            }
        case "vers":
            if resource.id == 1 {
                return NSLocalizedString("File Version", comment: "")
            } else if resource.id == 2 {
                return NSLocalizedString("Package Version", comment: "")
            }
        default:
            break
        }
        return NSLocalizedString("Untitled Resource", comment: "")
    }
}
