import Cocoa
import RFSupport

@NSApplicationMain
class ApplicationDelegate: NSObject, NSApplicationDelegate {
    // Don't configure prefs controller until needed
    private lazy var prefsController: NSWindowController = {
        ValueTransformer.setValueTransformer(LaunchActionTransformer(), forName: .launchActionTransformerName)
        let prefs = NSWindowController(windowNibName: "PrefsWindow")
        prefs.window?.center()
        return prefs
    }()
    
    override init() {
        NSApp.registerServicesMenuSendTypes([.string], returnTypes: [.string])
        UserDefaults.standard.register(defaults: [
            kConfirmChanges: false,
            kDeleteResourceWarning: true,
            kLaunchAction: kDisplayOpenPanel,
            kShowSidebar: true
        ])
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        SupportRegistry.scanForResources()
        // Load plugins
        NotificationCenter.default.addObserver(PluginRegistry.self, selector: #selector(PluginRegistry.bundleLoaded(_:)), name: Bundle.didLoadNotification, object: nil)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        if let plugins = Bundle.main.builtInPlugInsURL {
            self.scanForPlugins(folder: plugins)
        }
        for url in appSupport {
            self.scanForPlugins(folder: url.appendingPathComponent("ResForge/Plugins"))
        }
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
        let info = InfoWindowController.shared
        if info.window?.isKeyWindow == true {
            info.close()
        } else {
            info.showWindow(sender)
        }
    }
    
    @IBAction func showPrefs(_ sender: Any) {
        self.prefsController.showWindow(sender)
    }
    
    private func scanForPlugins(folder: URL) {
        let items: [URL]
        do {
            items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        } catch {
            return
        }
        for item in items where item.pathExtension == "plugin" {
            guard let plugin = Bundle(url: item) else {
                continue
            }
            SupportRegistry.scanForResources(in: plugin)
            plugin.load()
        }
    }
}
