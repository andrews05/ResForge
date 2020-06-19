import AVKit
import Cocoa

class SoundWindowController: NSWindowController, ResKnifePlugin {
    let resource: ResKnifeResource
    let sound: SoundResource
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

    override var windowNibName: String! {
        return "SoundWindow"
    }
    
    required init(resource: ResKnifeResource) {
        UserDefaults.standard.register(defaults: ["SndFormat":k16BitBigEndianFormat])
        self.resource = resource
        sound = SoundResource(resource.data!)
        super.init(window: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.soundDidPlayStop), name: .SoundDidStartPlaying, object: sound)
        NotificationCenter.default.addObserver(self, selector: #selector(self.soundDidPlayStop), name: .SoundDidStopPlaying, object: sound)
        self.window?.makeKeyAndOrderFront(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("not implemented")
    }
    
    deinit {
        sound.stop()
    }

    override func windowDidLoad() {
        super.windowDidLoad()
        self.format.stringValue = ""
        self.channels.stringValue = ""
        self.sampleRate.stringValue = ""
        self.duration.stringValue = ""
        self.loadInfo()
        sound.play()
    }
    
    func loadInfo() {
        if resource.data!.count == 0 {
            self.format.stringValue = "(empty)"
        } else if sound.format != 0 {
            if sound.valid {
                self.format.stringValue = SoundResource.supportedFormats[sound.format]!
                self.duration.stringValue = stringFromSeconds(sound.duration)
                playButton.isEnabled = true
                exportButton.isEnabled = true
            } else {
                let format = NSFileTypeForHFSTypeCode(OSType(sound.format))!
                self.format.stringValue = "\(format) (unsupported)"
            }
            self.channels.stringValue = sound.channels == 2 ? "Stereo" : "Mono"
            self.sampleRate.stringValue = String(format: "%.0f Hz", sound.sampleRate)
        } else {
            self.format.stringValue = "(unknown)"
        }
    }
    
    func stringFromSeconds(_ seconds: Double) -> String {
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
        if self.resource.name!.count > 0 {
            panel.nameFieldStringValue = self.resource.name!
        } else {
            panel.nameFieldStringValue = "Sound \(resource.resID)"
        }
        panel.allowedFileTypes = ["aiff"]
        panel.beginSheetModal(for: self.window!, completionHandler: { returnCode in
            if returnCode.rawValue == NSFileHandlingPanelOKButton {
                self.sound.export(to: panel.url!)
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
                self.sound.load(url: panel.url!, format: UInt32(format), channels: UInt32(channels), sampleRate: Double(sampleRate))
                do {
                    self.resource.data = try self.sound.data()
                } catch {

                }
                self.setDocumentEdited(true)
                self.loadInfo()
            }
        })
    }
}
