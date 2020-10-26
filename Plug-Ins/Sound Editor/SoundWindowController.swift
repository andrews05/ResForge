import AVKit
import Cocoa
import RKSupport

class SoundWindowController: NSWindowController, NSMenuItemValidation, ResKnifePlugin {
    let resource: Resource
    private let sound: SoundResource
    @IBOutlet var playButton: NSButton!
    @IBOutlet var exportButton: NSButton!
    @IBOutlet var format: NSTextField!
    @IBOutlet var channels: NSTextField!
    @IBOutlet var sampleRate: NSTextField!
    @IBOutlet var duration: NSTextField!
    @IBOutlet var accessoryView: NSView!
    @IBOutlet var selectFormat: NSPopUpButton!
    @IBOutlet var selectChannels: NSPopUpButton!
    @IBOutlet var selectSampleRate: NSPopUpButton!

    override var windowNibName: String {
        return "SoundWindow"
    }
    
    required init(resource: Resource) {
        UserDefaults.standard.register(defaults: ["SndFormat":k16BitBigEndianFormat])
        self.resource = resource
        sound = SoundResource(resource.data)
        super.init(window: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.soundDidPlayStop), name: .SoundDidStartPlaying, object: sound)
        NotificationCenter.default.addObserver(self, selector: #selector(self.soundDidPlayStop), name: .SoundDidStopPlaying, object: sound)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        sound.stop()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = self.resource.defaultWindowTitle
        self.loadInfo()
        sound.play()
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveResource(_:)),
             #selector(revertResource(_:)):
            return self.window!.isDocumentEdited
        default:
            return true
        }
    }
    
    private func loadInfo() {
        if sound.format != 0 {
            self.format.stringValue = SoundResource.formatNames[sound.format] ?? NSFileTypeForHFSTypeCode(OSType(sound.format))
            if sound.valid {
                self.duration.stringValue = stringFromSeconds(sound.duration)
            } else {
                self.format.stringValue += " (unsupported)"
            }
            self.channels.stringValue = sound.channels == 2 ? "Stereo" : "Mono"
            self.sampleRate.stringValue = String(format: "%.0f Hz", sound.sampleRate)
        } else if resource.data.isEmpty {
            self.format.stringValue = "(empty)"
        } else {
            self.format.stringValue = "(unknown)"
        }
        playButton.isEnabled = sound.valid
        exportButton.isEnabled = sound.valid
    }
    
    private func stringFromSeconds(_ seconds: Double) -> String {
        if seconds < 10 {
            return String(format: "%0.2fs", seconds)
        }
        if seconds < 60 {
            return String(format: "%0.1fs", seconds)
        }
        let s = Int(round(seconds))
        return String(format: "%02ld:%02ld", s / 60, s % 60)
    }
    
    @objc func soundDidPlayStop(_ notification: Notification) {
        DispatchQueue.main.async {
            self.playButton.title = self.sound.playing ? "Stop" : "Play"
        }
    }

    @IBAction func playSound(_ sender: Any) {
        sound.playing ? sound.stop() : sound.play()
    }
    
    @IBAction func exportSound(_ sender: Any) {
        let panel = NSSavePanel()
        if self.resource.name.count > 0 {
            panel.nameFieldStringValue = self.resource.name
        } else {
            panel.nameFieldStringValue = "Sound \(resource.id)"
        }
        panel.allowedFileTypes = ["aiff"]
        panel.beginSheetModal(for: self.window!, completionHandler: { returnCode in
            if returnCode.rawValue == NSFileHandlingPanelOKButton {
                do {
                    try self.sound.export(to: panel.url!)
                } catch let error {
                    self.presentError(error)
                }
            }
        })
    }
    
    @IBAction func importSound(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["public.audio"]
        panel.accessoryView = self.accessoryView
        panel.isAccessoryViewDisclosed = true
        panel.prompt = "Import"
        panel.beginSheetModal(for: self.window!, completionHandler: { returnCode in
            if returnCode.rawValue == NSFileHandlingPanelOKButton {
                let format = self.selectFormat.selectedTag()
                let channels = self.selectChannels.selectedTag()
                let sampleRate = self.selectSampleRate.selectedTag()
                do {
                    try self.sound.load(url: panel.url!, format: UInt32(format), channels: UInt32(channels), sampleRate: Double(sampleRate))
                    self.setDocumentEdited(true)
                } catch let error {
                    self.presentError(error)
                }
                self.loadInfo()
            }
        })
    }

    @IBAction func saveResource(_ sender: Any) {
        guard self.sound.valid else {
            return
        }
        do {
            self.resource.data = try self.sound.data()
            self.setDocumentEdited(false)
        } catch let error {
            self.presentError(error)
        }
    }

    @IBAction func revertResource(_ sender: Any) {
        sound.load(data: resource.data)
        self.loadInfo()
        self.setDocumentEdited(false)
    }
    
    // ResKnifePlugin protocol export functions
    static func filenameExtension(for resourceType: String) -> String? {
        return "aiff"
    }
    
    static func export(_ resource: Resource, to url: URL) -> Bool {
        let sound = SoundResource(resource.data)
        do {
            try sound.export(to: url)
        } catch let error {
            resource.document.presentError(error)
        }
        return true
    }
    
    static func icon(for resourceType: String) -> NSImage? {
        return NSWorkspace.shared.icon(forFileType: "public.audio")
    }
}
