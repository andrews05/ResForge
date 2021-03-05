import Cocoa
import RFSupport

struct ShanFlags: OptionSet {
    let rawValue: UInt16
    static let bankingFrames        = Self(rawValue: 0x0001)
    static let foldingFrames        = Self(rawValue: 0x0002)
    static let keyCarriedFrames     = Self(rawValue: 0x0004)
    static let animationFrames      = Self(rawValue: 0x0008)
    static let stopDisabled         = Self(rawValue: 0x0010)
    static let hideAltDisabled      = Self(rawValue: 0x0020)
    static let hideLightsDisabled   = Self(rawValue: 0x0040)
    static let unfoldsToFire        = Self(rawValue: 0x0080)
    static let pointingCorrection   = Self(rawValue: 0x0100)
}

class ShanWindowController: AbstractEditor, ResourceEditor {
    static let supportedTypes = ["shän"]
    
    let resource: Resource
    @IBOutlet var shanView: ShanView!
    @IBOutlet var forwardButton: NSButton!
    @IBOutlet var reverseButton: NSButton!
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
    @objc dynamic var framesPerSet = 0
    @objc dynamic var setCount = 1
    @objc dynamic var baseTransparency: Int16 = 0
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
    @objc dynamic var pointingCorrection = false
    
    @objc var gunPoints = ExitPoints(.red)
    @objc var turretPoints = ExitPoints(NSColor(red: 0, green: 0.75, blue: 1, alpha: 1))
    @objc var guidedPoints = ExitPoints(NSColor(red: 1, green: 0.75, blue: 0, alpha: 1))
    @objc var beamPoints = ExitPoints(.green)
    @objc dynamic var upCompressX: CGFloat = 100
    @objc dynamic var upCompressY: CGFloat = 100
    @objc dynamic var downCompressX: CGFloat = 100
    @objc dynamic var downCompressY: CGFloat = 100
    
    private(set) var currentFrame = 0
    private(set) var currentSet = 0
    private(set) var layers: [SpriteLayer] = []
    private(set) var pointLayers: [ExitPoints]
    private var spinTicks = 0
    private var setTicks = 0
    private var timer: Timer?
    private var playing = false {
        didSet {
            forwardButton.title = playing && forward ? "Pause" : "Play"
            (forward ? forwardButton : reverseButton)?.state = playing ? .on : .off
        }
    }
    private var forward = true {
        didSet {
            playing = forward == oldValue ? !playing : true
            (forward ? reverseButton : forwardButton)?.state = .off
        }
    }
    
    override var windowNibName: String {
        return "ShanWindow"
    }

    required init(resource: Resource) {
        self.resource = resource
        pointLayers = [
            gunPoints,
            turretPoints,
            guidedPoints,
            beamPoints
        ]
        super.init(window: nil)
        for points in pointLayers {
            for point in points.points {
                point.controller = self
            }
        }
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
        playing = true
        timer = Timer(timeInterval: 1/30, target: self, selector: #selector(nextFrame), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    @objc private func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == " " {
            playing = !playing
        } else if event.specialKey == .leftArrow {
            // If playing in the opposite direction then switch direction, else step by 1 frame
            if playing && forward {
                forward = false
            } else {
                forward = false
                playing = false
                currentFrame = (currentFrame + framesPerSet - 1) % framesPerSet
            }
        } else if event.specialKey == .rightArrow {
            if playing && !forward {
                forward = true
            } else {
                forward = true
                playing = false
                currentFrame = (currentFrame + 1) % framesPerSet
            }
        }
    }
    
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        if key != "enabled" {
            self.setDocumentEdited(true)
        }
    }
    
    // MARK: -
    
    @IBAction func forward(_ sender: Any) {
        forward = true
    }
    
    @IBAction func reverse(_ sender: Any) {
        forward = false
    }
    
    @objc private func nextFrame() {
        guard framesPerSet > 0 && setCount > 0 else {
            frameCounter.stringValue = "-/-"
            return
        }
        if playing {
            // Spin slower when fewer frames
            spinTicks = (spinTicks + 1) % (72/framesPerSet + 1)
            if spinTicks == 0 {
                currentFrame += forward ? 1 : framesPerSet-1
                currentFrame %= framesPerSet
                // For banking, cycle through sets each full rotation
                if enabled && extraFrames == ShanFlags.bankingFrames.rawValue && currentFrame == 0 {
                    currentSet = (currentSet + 1) % setCount
                }
            }
        }
        switch ShanFlags(rawValue: extraFrames) {
        case .bankingFrames:
            if !enabled {
                currentSet = 0
            }
        case .foldingFrames:
            // Animate to last set and back again
            if (enabled && currentSet < (setCount-1)) || (!enabled && currentSet > 0) {
                setTicks += 1
                if setTicks >= animationDelay {
                    currentSet += enabled ? 1 : -1
                    setTicks = 0
                }
            }
        case .keyCarriedFrames:
            // Toggle between 1st and 2nd set
            currentSet = (enabled && setCount > 0) ? 1 : 0
        case .animationFrames:
            // Continuous cycle
            if !enabled {
                currentSet = 0
            } else {
                setTicks += 1
                if setTicks >= animationDelay {
                    currentSet = (currentSet + 1) % setCount
                    setTicks = 0
                }
            }
        default:
            currentSet = 0
        }
        for layer in layers {
            layer.nextFrame()
        }
        let frameIndex = (currentSet * framesPerSet) + currentFrame
        frameCounter.stringValue = "\(frameIndex+1)/\(framesPerSet*setCount)"
        shanView.needsDisplay = true
    }
    
    // MARK: -
    
    private func load() {
        guard !resource.data.isEmpty else {
            return
        }
        do {
            let reader = BinaryDataReader(resource.data)
            baseLayer.spriteID = try reader.read()
            baseLayer.maskID = try reader.read()
            setCount = Int(try reader.read() as Int16)
            baseLayer.width = try reader.read()
            baseLayer.height = try reader.read()
            baseTransparency = try reader.read()
            altLayer.spriteID = try reader.read()
            altLayer.maskID = try reader.read()
            altLayer.setCount = Int(try reader.read() as Int16)
            altLayer.width = try reader.read()
            altLayer.height = try reader.read()
            for layer in [engineLayer!, lightLayer!, weaponLayer!] {
                layer.spriteID = try reader.read()
                layer.maskID = try reader.read()
                layer.width = try reader.read()
                layer.height =  try reader.read()
            }
            
            let flags = ShanFlags(rawValue: try reader.read())
            // Use first matching flag for extraFrames, in case multiple values have been set
            let frameFlags: [ShanFlags] = [
                .bankingFrames,
                .foldingFrames,
                .keyCarriedFrames,
                .animationFrames
            ]
            extraFrames = frameFlags.first(where: { flags.contains($0) })?.rawValue ?? 0
            // Folding flag indicates glow on banking when combined with banking flag
            glowOnBank = extraFrames == ShanFlags.bankingFrames.rawValue && flags.contains(.foldingFrames)
            stopDisabled = flags.contains(.stopDisabled)
            altLayer.hideDisabled = flags.contains(.hideAltDisabled)
            lightLayer.hideDisabled = flags.contains(.hideLightsDisabled)
            unfoldsToFire = flags.contains(.unfoldsToFire)
            pointingCorrection = flags.contains(.pointingCorrection)
            
            animationDelay = try reader.read()
            weaponLayer.decay = try reader.read()
            framesPerSet = Int(try reader.read() as Int16)
            lightLayer.blinkMode = try reader.read()
            if (!(0...3 ~= lightLayer.blinkMode)) {
                lightLayer.blinkMode = 0
            }
            lightLayer.blinkValueA = try reader.read()
            lightLayer.blinkValueB = try reader.read()
            lightLayer.blinkValueC = try reader.read()
            lightLayer.blinkValueD = try reader.read()
            shieldLayer.spriteID = try reader.read()
            shieldLayer.maskID = try reader.read()
            shieldLayer.width = try reader.read()
            shieldLayer.height =  try reader.read()
            for points in pointLayers {
                for point in points.points {
                    point.x = CGFloat(try reader.read() as Int16)
                }
                for point in points.points {
                    point.y = CGFloat(try reader.read() as Int16)
                }
            }
            upCompressX = CGFloat(try reader.read() as Int16)
            upCompressY = CGFloat(try reader.read() as Int16)
            downCompressX = CGFloat(try reader.read() as Int16)
            downCompressY = CGFloat(try reader.read() as Int16)
            for points in pointLayers {
                for point in points.points {
                    point.z = CGFloat(try reader.read() as Int16)
                }
            }
            
            self.setDocumentEdited(false)
        } catch {}
    }

    @IBAction func saveResource(_ sender: Any) {
        let writer = BinaryDataWriter()
        writer.write(baseLayer.spriteID)
        writer.write(baseLayer.maskID)
        writer.write(Int16(setCount))
        writer.write(baseLayer.width)
        writer.write(baseLayer.height)
        writer.write(baseTransparency)
        writer.write(altLayer.spriteID)
        writer.write(altLayer.maskID)
        writer.write(Int16(altLayer.setCount))
        writer.write(altLayer.width)
        writer.write(altLayer.height)
        for layer in [engineLayer!, lightLayer!, weaponLayer!] {
            writer.write(layer.spriteID)
            writer.write(layer.maskID)
            writer.write(layer.width)
            writer.write(layer.height)
        }
        var flags = ShanFlags(rawValue: extraFrames)
        if flags.contains(.bankingFrames) && glowOnBank {
            flags.insert(.foldingFrames)
        }
        if stopDisabled {
            flags.insert(.stopDisabled)
        }
        if altLayer.hideDisabled {
            flags.insert(.hideAltDisabled)
        }
        if lightLayer.hideDisabled {
            flags.insert(.hideLightsDisabled)
        }
        if unfoldsToFire {
            flags.insert(.unfoldsToFire)
        }
        if pointingCorrection {
            flags.insert(.pointingCorrection)
        }
        writer.write(flags.rawValue)
        writer.write(animationDelay)
        writer.write(weaponLayer.decay)
        writer.write(Int16(framesPerSet))
        writer.write(lightLayer.blinkMode)
        writer.write(lightLayer.blinkValueA)
        writer.write(lightLayer.blinkValueB)
        writer.write(lightLayer.blinkValueC)
        writer.write(lightLayer.blinkValueD)
        writer.write(shieldLayer.spriteID)
        writer.write(shieldLayer.maskID)
        writer.write(shieldLayer.width)
        writer.write(shieldLayer.height)
        for points in pointLayers {
            for point in points.points {
                writer.write(Int16(point.x))
            }
            for point in points.points {
                writer.write(Int16(point.y))
            }
        }
        writer.write(Int16(upCompressX))
        writer.write(Int16(upCompressY))
        writer.write(Int16(downCompressX))
        writer.write(Int16(downCompressY))
        for points in pointLayers {
            for point in points.points {
                writer.write(Int16(point.z))
            }
        }
        // Extra 16 bytes at end of resource
        writer.write(0 as UInt64)
        writer.write(0 as UInt64)
        resource.data = writer.data
    }

    @IBAction func revertResource(_ sender: Any) {
        self.load()
    }
}

// Allow the window to be first responder so it can respond to key events for playback
class ShanWindowView: NSView {
    override var acceptsFirstResponder: Bool { true }
}
