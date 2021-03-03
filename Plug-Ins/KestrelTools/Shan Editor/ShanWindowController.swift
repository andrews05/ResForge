import Cocoa
import RFSupport

class ShanWindowController: NSWindowController, NSMenuItemValidation, ResourceEditor, NSAnimationDelegate {
    static let supportedTypes = ["shän"]
    
    let resource: Resource
    @IBOutlet var shanView: ShanView!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    @IBOutlet var unfoldsCheckbox: NSButton!
    @IBOutlet var bankGlowCheckbox: NSButton!
    @IBOutlet var baseLayer: BaseLayer!
    @IBOutlet var altLayer: AltLayer!
    @IBOutlet var engineLayer: EngineLayer!
    @IBOutlet var lightLayer: LightLayer!
    @IBOutlet var weaponLayer: WeaponLayer!
    @IBOutlet var shieldLayer: ShieldLayer!
    
    @objc var enabled = true
    @objc dynamic var framesPerSet: Int = 0
    @objc dynamic var baseSets: Int = 0
    @objc dynamic var animationDelay: Int16 = 0
    @objc dynamic var extraFrames: UInt16 = 0 {
        didSet {
            unfoldsCheckbox.isHidden = extraFrames != ShanFlags.foldingFrames.rawValue
            bankGlowCheckbox.isHidden = extraFrames != ShanFlags.bankingFrames.rawValue
        }
    }
    @objc dynamic var unfoldsToFire = false
    @objc dynamic var glowOnBank = false
    @objc dynamic var stopDisabled = false
    
    private(set) var currentFrame = 0
    private(set) var currentSet = 0
    private(set) var layers: [SpriteLayer] = []
    private var frameCount = 0
    private var tickCount = 0
    private var shan = Shan()
    private var timer: Timer?
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
            lightLayer,
            weaponLayer,
            shieldLayer
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
            currentFrame = (currentFrame + framesPerSet - 1) % framesPerSet
        } else if event.specialKey == .rightArrow {
            playing = false
            currentFrame = (currentFrame + 1) % framesPerSet
        }
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        if key != "enabled" {
            self.setDocumentEdited(true)
        }
    }
    
    // MARK: -
    
    private func load() {
        if !resource.data.isEmpty {
            try? shan.read(BinaryDataReader(resource.data))
        }
        animationDelay = shan.animationDelay
        // Use first matching flag for extraFrames, in case multiple values have been set
        let frameFlags: [ShanFlags] = [
            .bankingFrames,
            .foldingFrames,
            .keyCarriedFrames,
            .animationFrames
        ]
        extraFrames = frameFlags.first(where: { shan.flags.contains($0) })?.rawValue ?? 0
        unfoldsToFire = shan.flags.contains(.unfoldsToFire)
        // Folding flag indicates glow on banking when combined with banking
        glowOnBank = extraFrames == ShanFlags.bankingFrames.rawValue && shan.flags.contains(.foldingFrames)
        stopDisabled = shan.flags.contains(.stopDisabled)
        for layer in layers {
            layer.load(shan)
        }
        framesPerSet = Int(shan.framesPerSet)
        baseSets = Int(shan.baseSets)
        playing = true
        self.setDocumentEdited(false)
    }
    
    @objc private func nextFrame() {
        guard framesPerSet > 0 && baseSets > 0 else {
            frameCounter.stringValue = "-/-"
            return
        }
        if playing {
            // Rotate slower when fewer frames
            if tickCount == 0 {
                // For banking, cycle through sets each full rotation
                if enabled && extraFrames == ShanFlags.bankingFrames.rawValue && currentFrame == framesPerSet-1 {
                    currentSet = (currentSet + 1) % baseSets
                }
                currentFrame = (currentFrame + 1) % framesPerSet
            }
            tickCount = (tickCount + 1) % (72/framesPerSet+1)
        }
        switch ShanFlags(rawValue: extraFrames) {
        case .bankingFrames:
            if !enabled {
                currentSet = 0
            }
        case .foldingFrames:
            // Animate to last set and back again
            if enabled && currentSet < (baseSets-1) {
                frameCount += 1
                if frameCount >= animationDelay {
                    currentSet += 1
                    frameCount = 0
                }
            } else if !enabled && currentSet > 0 {
                frameCount += 1
                if frameCount >= animationDelay {
                    currentSet -= 1
                    frameCount = 0
                }
            }
        case .keyCarriedFrames:
            // Toggle between 1st and 2nd set
            currentSet = (enabled && baseSets > 0) ? 1 : 0
        case .animationFrames:
            // Continuous cycle
            if !enabled {
                currentSet = 0
            } else {
                frameCount += 1
                if frameCount >= animationDelay {
                    currentSet = (currentSet + 1) % baseSets
                    frameCount = 0
                }
            }
        default:
            currentSet = 0
        }
        for layer in layers {
            layer.nextFrame()
        }
        let frameIndex = (currentSet * framesPerSet) + currentFrame
        let total = framesPerSet * baseSets
        frameCounter.stringValue = "\(frameIndex+1)/\(total)"
        shanView.needsDisplay = true
    }
    
    // MARK: -

    @IBAction func saveResource(_ sender: Any) {
        
    }

    @IBAction func revertResource(_ sender: Any) {
        self.load()
    }
}
