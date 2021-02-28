import Cocoa
import RFSupport

class ShanWindowController: NSWindowController, NSMenuItemValidation, ResourceEditor, NSAnimationDelegate {
    static let supportedTypes = ["shän"]
    
    let resource: Resource
    var shan = Shan()
    var currentFrame = 0
    private var timer: Timer?
    private var animation: NSAnimation?
    @IBOutlet var shanView: ShanView!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    
    var layers: [SpriteLayer] = []
    @IBOutlet var baseLayer: BaseLayer!
    @IBOutlet var altLayer: AltLayer!
    @IBOutlet var engineLayer: EngineLayer!
    @IBOutlet var lightLayer: LightLayer!
    @IBOutlet var weaponLayer: WeaponLayer!
    @IBOutlet var shieldLayer: ShieldLayer!
    
    @objc dynamic var framesPerSet: Int16 = 0
    @objc dynamic var baseSets: Int16 = 0
    var totalFrames: Int {
        return Int(framesPerSet * baseSets)
    }
    
    private var playing = false {
        didSet {
            playButton.title = playing ? "Pause" : "Play"
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
        layers = [
            baseLayer,
            altLayer,
            engineLayer,
            lightLayer
        ]
        self.load()
        timer = Timer(timeInterval: 1/30, target: self, selector: #selector(nextFrame), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
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
            currentFrame = (currentFrame+totalFrames-2) % totalFrames
            self.nextFrame()
        } else if event.specialKey == .rightArrow {
            playing = false
            self.nextFrame()
        }
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        self.setDocumentEdited(true)
    }
    
    // MARK: -
    
    private func load() {
        if resource.data.isEmpty {
            shan.baseSprite = Int16(resource.id - 128 + 1000)
        } else {
            do {
                try shan.read(BinaryDataReader(resource.data))
            } catch {}
        }
        framesPerSet = shan.framesPerSet
        baseSets = shan.baseSets
        for layer in layers {
            layer.load(shan)
        }
        self.updateView()
        self.setDocumentEdited(false)
    }
    
    private func updateView() {
        playing = false
        if !baseLayer.frames.isEmpty {
            playButton.isEnabled = totalFrames > 1
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
    }
    
    @objc private func nextFrame() {
        if playing {
            currentFrame = (currentFrame + 1) % totalFrames
            frameCounter.stringValue = "\(currentFrame+1)/\(totalFrames)"
        }
        for layer in layers {
            layer.nextFrame()
        }
        shanView.needsDisplay = true
    }
    
    // MARK: -

    @IBAction func saveResource(_ sender: Any) {
        
    }

    @IBAction func revertResource(_ sender: Any) {
        self.load()
    }
}
