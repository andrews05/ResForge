import Cocoa
import RFSupport

class ShanWindowController: NSWindowController, NSMenuItemValidation, ResourceEditor {
    static let supportedTypes = ["shän"]
    
    let resource: Resource
    private var shan = Shan()
    private(set) var baseFrames: [NSBitmapImageRep] = []
    private(set) var altFrames: [NSBitmapImageRep] = []
    private(set) var glowFrames: [NSBitmapImageRep] = []
    private(set) var lightFrames: [NSBitmapImageRep] = []
    private(set) var currentFrame = 0
    private var timer: Timer?
    @IBOutlet var shanView: ShanView!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    @IBOutlet var baseLink: NSButton!
    @IBOutlet var altLink: NSButton!
    @IBOutlet var glowLink: NSButton!
    @IBOutlet var lightLink: NSButton!
    
    @objc var framesPerSet: Int16 {
        get {
            return shan.framesPerSet
        }
        set {
            shan.framesPerSet = newValue
        }
    }
    @objc var baseSets: Int16 {
        get {
            return shan.baseSets
        }
        set {
            shan.baseSets = newValue
        }
    }
    @objc var baseID: Int16 {
        get {
            return shan.baseID
        }
        set {
            shan.baseID = newValue
            baseFrames = self.loadRle(id: shan.baseID)
            baseLink.title = self.rleInfo(frames: baseFrames)
        }
    }
    @objc var altID: Int16 {
        get {
            return shan.altID
        }
        set {
            shan.altID = newValue
            altFrames = self.loadRle(id: shan.altID)
            altLink.title = self.rleInfo(frames: altFrames)
        }
    }
    @objc var glowID: Int16 {
        get {
            return shan.glowID
        }
        set {
            shan.glowID = newValue
            glowFrames = self.loadRle(id: shan.glowID)
            glowLink.title = self.rleInfo(frames: glowFrames)
        }
    }
    @objc var lightID: Int16 {
        get {
            return shan.lightID
        }
        set {
            shan.lightID = newValue
            lightFrames = self.loadRle(id: shan.lightID)
            lightLink.title = self.rleInfo(frames: lightFrames)
        }
    }
    
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
        self.loadShan()
        NotificationCenter.default.addObserver(self, selector: #selector(self.windowWillClose(_:)), name: NSWindow.willCloseNotification, object: self.window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle
        shanView.shanController = self
        self.updateView()
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
        if resource.data.isEmpty {
            shan.baseID = Int16(resource.id - 128 + 1000)
        } else {
            do {
                try shan.read(BinaryDataReader(resource.data))
            } catch {}
        }
        baseFrames = self.loadRle(id: shan.baseID)
        altFrames = self.loadRle(id: shan.altID)
        glowFrames = self.loadRle(id: shan.glowID)
        lightFrames = self.loadRle(id: shan.lightID)
    }
    
    private func loadRle(id: Int16) -> [NSBitmapImageRep] {
        guard id > 0, let rleResource = resource.manager.findResource(ofType: "rlëD", id: Int(id), currentDocumentOnly: false) else {
            return []
        }
        var frames: [NSBitmapImageRep] = []
        do {
            let rle = try Rle(rleResource.data)
            for _ in 0..<rle.frameCount {
                frames.append(try rle.readFrame())
            }
        } catch {
            return []
        }
        return frames
    }
    
    private func rleInfo(frames: [NSBitmapImageRep]) -> String {
        return frames.isEmpty ? "not found" : "\(frames[0].pixelsWide)x\(frames[0].pixelsHigh), \(frames.count)"
    }
    
    @objc private func nextFrame() {
        currentFrame = (currentFrame + 1) % baseFrames.count
        shanView.needsDisplay = true
        frameCounter.stringValue = "\(currentFrame+1)/\(baseFrames.count)"
    }
    
    private func updateView() {
        playing = false
        if !baseFrames.isEmpty {
            playButton.isEnabled = baseFrames.count > 1
            currentFrame = -1
            if playButton.isEnabled {
                playing = true
            } else {
                nextFrame()
            }
        } else {
            playButton.isEnabled = false
            frameCounter.stringValue = "-/-"
        }
        baseLink.title = self.rleInfo(frames: baseFrames)
        altLink.title = self.rleInfo(frames: altFrames)
        glowLink.title = self.rleInfo(frames: glowFrames)
        lightLink.title = self.rleInfo(frames: lightFrames)
    }
    
    // MARK: -

    @IBAction func saveResource(_ sender: Any) {
        
    }

    @IBAction func revertResource(_ sender: Any) {
        self.loadShan()
        self.updateView()
        self.setDocumentEdited(false)
    }
}
