import Cocoa
import RKSupport

class AnimationWindowController: NSWindowController, NSMenuItemValidation, ResKnifePlugin {
    static let editedTypes = ["rlëD"]
    
    let resource: Resource
    private var rle: Rle!
    private var frames: [NSBitmapImageRep] = []
    private var currentFrame = 0
    private var timer: Timer?
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var exportButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    @IBOutlet var importPanel: AnimationImporter!
    
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
        return "AnimationWindow"
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
        imageView.allowsCutCopyPaste = false
        self.loadImage()
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
            currentFrame = (currentFrame+frames.count-2) % frames.count
            self.nextFrame()
        } else if event.specialKey == .rightArrow {
            playing = false
            self.nextFrame()
        }
    }
    
    // MARK: -
    
    private func loadImage() {
        rle = nil
        frames.removeAll()
        if !resource.data.isEmpty {
            do {
                rle = try Rle(resource.data)
                for _ in 0..<rle.frameCount {
                    frames.append(try rle.readFrame())
                }
            } catch {}
        }
        self.updateView()
    }
    
    @objc private func nextFrame() {
        guard let image = imageView.image else {
            return
        }
        currentFrame = (currentFrame + 1) % frames.count
        if !image.representations.isEmpty {
            image.removeRepresentation(image.representations[0])
        }
        image.addRepresentation(frames[currentFrame])
        imageView.setNeedsDisplay()
        frameCounter.stringValue = "\(currentFrame+1)/\(frames.count)"
    }
    
    private func updateView() {
        playing = false
        if !frames.isEmpty {
            imageView.image = NSImage(size: frames[0].size)
            let width = max(frames[0].size.width, window!.contentMinSize.width)
            let height = max(frames[0].size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSMakeSize(width, height))
            imageSize.stringValue = "\(frames[0].pixelsWide)x\(frames[0].pixelsHigh)"
            playButton.isEnabled = frames.count > 1
            exportButton.isEnabled = true
            currentFrame = -1
            if playButton.isEnabled {
                playing = true
            } else {
                nextFrame()
            }
        } else {
            imageView.image = nil
            playButton.isEnabled = false
            exportButton.isEnabled = false
            imageSize.stringValue = resource.data.isEmpty ? "No data" : "Invalid data"
            frameCounter.stringValue = "-/-"
        }
    }
    
    // MARK: -
    
    @IBAction func importImage(_ sender: Any) {
        playing = false
        importPanel.beginSheetModal(for: self.window!) { [self] (image, gridX, gridY) in
            rle = Rle(image: image, gridX: gridX, gridY: gridY)
            frames = []
            for _ in 0..<rle.frameCount {
                frames.append(rle.writeFrame())
            }
            self.updateView()
            self.setDocumentEdited(true)
        }
    }
    
    @IBAction func exportImage(_ sender: Any) {
        let panel = NSSavePanel()
        if self.resource.name.isEmpty {
            panel.nameFieldStringValue = "Frame sheet \(resource.id)"
        } else {
            panel.nameFieldStringValue = self.resource.name
        }
        panel.allowedFileTypes = ["tiff"]
        panel.beginSheetModal(for: self.window!) { returnCode in
            if returnCode == .OK {
                do {
                    let data = try self.rle.readSheet().tiffRepresentation!
                    try data.write(to: panel.url!)
                } catch {
                    self.presentError(error)
                }
            }
        }
    }

    @IBAction func saveResource(_ sender: Any) {
        guard let rle = rle else {
            return
        }
        resource.data = rle.data
        self.setDocumentEdited(false)
    }

    @IBAction func revertResource(_ sender: Any) {
        self.loadImage()
        self.setDocumentEdited(false)
    }
    
    @IBAction func copy(_ sender: Any) {
        if let image = imageView.image {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
        }
    }
    
    // MARK: -
    static func filenameExtension(for resourceType: String) -> String? {
        return "tiff"
    }
    
    static func export(_ resource: Resource, to url: URL) -> Bool {
        var data = resource.data
        switch resource.type {
        case "rlëD":
            do {
                data = try Rle(data).readSheet().tiffRepresentation!
            } catch {
                data = Data()
            }
        default:
            break
        }
        do {
            try data.write(to: url)
        } catch let error {
            resource.document?.presentError(error)
        }
        return true
    }
    
    static func image(for resource: Resource) -> NSImage? {
        guard !resource.data.isEmpty else {
            return nil
        }
        switch resource.type {
        case "rlëD":
            guard let rle = try? Rle(resource.data),
                  let frame = try? rle.readFrame()
            else { return nil }
            let image = NSImage(size: NSMakeSize(CGFloat(rle.frameWidth), CGFloat(rle.frameHeight)))
            image.addRepresentation(frame)
            return image
        default:
            return nil
        }
    }
    
    static func icon(for resourceType: String) -> NSImage? {
        return NSWorkspace.shared.icon(forFileType: "public.image")
    }
    
    static func previewSize(for resourceType: String) -> Int? {
        return 100
    }
}

class AnimationBox: NSBox {
    // Toggle black background on click
    override func mouseDown(with event: NSEvent) {
        self.borderColor = self.borderColor == .gridColor ? .quaternaryLabelColor : .gridColor
        self.fillColor = self.fillColor == .black ? .gridColor : .black
    }
}
