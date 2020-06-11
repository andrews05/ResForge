import AVKit
import Cocoa

class SoundWindowController: NSWindowController, ResKnifePlugin {
    var resource: ResKnifeResource
    var sound: SoundResource?
    @IBOutlet var playButton: NSButton!
    @IBOutlet var exportButton: NSButton!
    @IBOutlet var format: NSTextField!
    @IBOutlet var channels: NSTextField!
    @IBOutlet var sampleRate: NSTextField!
    @IBOutlet var duration: NSTextField!

    override var windowNibName: String! {
        return "SoundWindow"
    }
    
    required init(resource: ResKnifeResource) {
        self.resource = resource
        super.init(window: nil)

        if resource.data!.count > 0 {
            sound = SoundResource(resource: resource)
        }
        self.window?.makeKeyAndOrderFront(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented. Use init()")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.channels.stringValue = ""
        self.sampleRate.stringValue = ""
        self.duration.stringValue = ""
        if let sound = sound {
            if sound.format != 0 {
                if sound.valid {
                    self.format.stringValue = SoundResource.supportedFormats[sound.format]!
                    self.duration.stringValue = stringFromSeconds(sound.duration)
                    playButton.isEnabled = true
                    exportButton.isEnabled = true
                    sound.play()
                } else {
                    let format = NSFileTypeForHFSTypeCode(OSType(sound.format))!
                    self.format.stringValue = "\(format) (unsupported)"
                }
                self.channels.stringValue = sound.channels == 2 ? "Stereo" : "Mono"
                self.sampleRate.stringValue = String(format: "%.0f Hz", sound.sampleRate)
            } else {
                self.format.stringValue = "(unknown)"
            }
        } else {
            self.format.stringValue = "(empty)"
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
    
    deinit {
        sound?.stop()
    }

    @IBAction func playSound(_ sender: Any) {
        sound?.play()
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
                self.sound!.export(to: panel.url!)
            }
        })
    }
    
    @IBAction func importSound(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["public.audio"]
        panel.beginSheetModal(for: self.window!, completionHandler: { returnCode in
            if returnCode.rawValue == NSFileHandlingPanelOKButton {
                self.sound = SoundResource(url: panel.url!, format: k16BitBigEndianFormat, channels: 0, sampleRate: 0)
            }
        })
    }
}
