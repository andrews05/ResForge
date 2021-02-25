import Cocoa
import RFSupport

class ShanWindowController: NSWindowController, NSMenuItemValidation, ResourceEditor {
    static let supportedTypes = ["shän"]
    
    let resource: Resource
    private var shan: Shan!
    var baseFrames: [NSBitmapImageRep] = []
    var glowFrames: [NSBitmapImageRep] = []
    var lightFrames: [NSBitmapImageRep] = []
    var currentFrame = 0
    private var timer: Timer?
    @IBOutlet var shanView: ShanView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    
    private var playing = false {
        didSet {
            playButton.title = playing ? "Pause" : "Play"
            timer?.invalidate()
            if playing {
                timer = Timer(timeInterval: 1/30, target: self, selector: #selector(nextFrame), userInfo: nil, repeats: true)
                RunLoop.main.add(timer!, forMode: .default)
            }
        }
    }
    
    override var windowNibName: String {
        return "ShanWindow"
    }

    required init(resource: Resource) {
        self.resource = resource
        super.init(window: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.windowWillClose(_:)), name: NSWindow.willCloseNotification, object: self.window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle
        shanView.shanController = self
        self.loadShan()
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
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
    
    @IBAction func playPause(_ sender: Any) {
        playing = !playing
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == " " {
            playing = !playing
        } else if event.specialKey == .leftArrow {
            playing = false
            currentFrame = (currentFrame+baseFrames.count-2) % baseFrames.count
            self.nextFrame()
        } else if event.specialKey == .rightArrow {
            playing = false
            self.nextFrame()
        }
    }
    
    // MARK: -
    
    private func loadShan() {
        if !resource.data.isEmpty {
            do {
                shan = try Shan(resource.data)
                baseFrames = try self.loadRle(id: shan.base)
                glowFrames = try self.loadRle(id: shan.glow)
                lightFrames = try self.loadRle(id: shan.lights)
            } catch {}
        }
        self.updateView()
    }
    
    private func loadRle(id: UInt16) throws -> [NSBitmapImageRep] {
        guard let rleResource = resource.manager.findResource(ofType: "rlëD", id: Int(id), currentDocumentOnly: false) else {
            return []
        }
        var frames: [NSBitmapImageRep] = []
        let rle = try Rle(rleResource.data)
        for _ in 0..<rle.frameCount {
            frames.append(try rle.readFrame())
        }
        return frames
    }
    
    @objc private func nextFrame() {
        currentFrame = (currentFrame + 1) % baseFrames.count
        shanView.needsDisplay = true
        frameCounter.stringValue = "\(currentFrame+1)/\(baseFrames.count)"
    }
    
    private func updateView() {
        playing = false
        if !baseFrames.isEmpty {
            let width = max(baseFrames[0].size.width, window!.contentMinSize.width)
            let height = max(baseFrames[0].size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSMakeSize(width, height))
            imageSize.stringValue = "\(baseFrames[0].pixelsWide)x\(baseFrames[0].pixelsHigh)"
            playButton.isEnabled = baseFrames.count > 1
            currentFrame = -1
            if playButton.isEnabled {
                playing = true
            } else {
                nextFrame()
            }
        } else {
            playButton.isEnabled = false
            imageSize.stringValue = resource.data.isEmpty ? "No data" : "Invalid data"
            frameCounter.stringValue = "-/-"
        }
    }
    
    // MARK: -

    @IBAction func saveResource(_ sender: Any) {
        
    }

    @IBAction func revertResource(_ sender: Any) {
        self.loadShan()
        self.setDocumentEdited(false)
    }
}
