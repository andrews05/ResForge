import AppKit
import RFSupport

import HexEditor
import TemplateEditor
import DialogEditor
import ImageEditor
import MenuEditor
import NovaTools
import SoundEditor

let plugins: [RFPlugin.Type] = [
    HexEditor.self,
    TemplateEditor.self,
    DialogEditor.self,
    ImageEditor.self,
    MenuEditor.self,
    NovaTools.self,
    SoundEditor.self,
]

@main
class ApplicationDelegate: NSObject, NSApplicationDelegate {
    static let githubURL = "https://github.com/andrews05/ResForge"

    private lazy var prefsController = PrefsController()

    override init() {
        NSApp.registerServicesMenuSendTypes([.string], returnTypes: [.string])
        RFDefaults.register()
    }

    func applicationSupportsSecureRestorableState(_ application: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load plugins and support resources
        for plugin in plugins {
            plugin.register()
            SupportRegistry.scanForResources(in: plugin.bundle)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .allDomainsMask)
        for url in appSupport {
            SupportRegistry.scanForResources(in: url.appendingPathComponent("ResForge"))
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        // Abort open panel when opening a document by other means
        if sender.modalWindow is NSOpenPanel {
            sender.abortModal()
        }
        return false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        let launchAction = UserDefaults.standard.string(forKey: RFDefaults.launchAction)
        switch launchAction {
        case RFDefaults.LaunchAction.OpenUntitledFile.rawValue:
            return true
        case RFDefaults.LaunchAction.DisplayOpenPanel.rawValue:
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

    @IBAction func viewWebsite(_ sender: Any) {
        if let url = URL(string: Self.githubURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
