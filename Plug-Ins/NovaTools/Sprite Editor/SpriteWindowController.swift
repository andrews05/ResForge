import Cocoa
import RFSupport

class SpriteWindowController: AbstractEditor, ResourceEditor, PreviewProvider, ExportProvider {
    static let supportedTypes = ["rlëD", "rlëX", "SMIV"]
    private static let typeMap: [String: Sprite.Type] = [
        "rlëD": SpriteWorld.self,
        "rlëX": RleX.self,
        "SMIV": ShapeMachine.self,
    ]
    
    let resource: Resource
    private var sprite: Sprite!
    private var frames: [NSBitmapImageRep] = []
    private var currentFrame = 0
    private var timer: Timer?
    private var writeableType: WriteableSprite.Type? {
        return Self.typeMap[resource.typeCode] as? WriteableSprite.Type
    }
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var exportButton: NSButton!
    @IBOutlet var importButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    @IBOutlet var importPanel: SpriteImporter!
    
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
        return "SpriteWindow"
    }

    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        self.window?.title = resource.defaultWindowTitle
        imageView.allowsCutCopyPaste = false
        importButton.isHidden = writeableType == nil
        importPanel.dither.isHidden = resource.typeCode != "rlëD"
        self.loadImage()
    }
    
    @objc func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
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
        sprite = nil
        frames.removeAll()
        guard let spriteType = Self.typeMap[resource.typeCode] else {
            return
        }
        if !resource.data.isEmpty {
            do {
                sprite = try spriteType.init(resource.data)
                let t = Date.timeIntervalSinceReferenceDate
                for _ in 0..<sprite.frameCount {
                    frames.append(try sprite.readFrame())
                }
                print(Date.timeIntervalSinceReferenceDate - t)
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
        image.size = frames[currentFrame].size
        imageView.needsDisplay = true
        frameCounter.stringValue = "\(currentFrame+1)/\(frames.count)"
    }
    
    private func updateView() {
        playing = false
        if !frames.isEmpty {
            // Shrink the window
            window?.setContentSize(window!.contentMinSize)
            // Expand to fit
            imageView.image = NSImage(size: NSSize(width: sprite.frameWidth, height: sprite.frameHeight))
            imageSize.stringValue = "\(sprite.frameWidth)x\(sprite.frameHeight)"
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
        importPanel.beginSheetModal(for: self.window!, sheetCallback: self.importSheet, framesCallback: self.importFrames)
    }
    
    @IBAction func saveResource(_ sender: Any) {
        guard let sprite = sprite else {
            return
        }
        resource.data = sprite.data
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
    
    @IBAction func paste(_ sender: Any) {
        guard writeableType != nil,
              let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage
        else {
            return
        }
        importPanel.beginSheetModal(for: window!, with: image, sheetCallback: self.importSheet)
    }
    
    private func importSheet(image: NSImage, gridX: Int, gridY: Int, dither: Bool) {
        guard let spriteType = writeableType else {
            return
        }
        let rep = image.representations[0]
        let newSprite = spriteType.init(width: rep.pixelsWide / gridX, height: rep.pixelsHigh / gridY, count: gridX * gridY)
        sprite = newSprite
        let t = Date.timeIntervalSinceReferenceDate
        frames = newSprite.writeSheet(image, dither: dither)
        print(Date.timeIntervalSinceReferenceDate - t)
        self.updateView()
        self.setDocumentEdited(true)
    }
    
    private func importFrames(images: [NSImage], dither: Bool) {
        guard let spriteType = writeableType else {
            return
        }
        let rep = images[0].representations[0]
        let newSprite = spriteType.init(width: rep.pixelsWide, height: rep.pixelsHigh, count: images.count)
        sprite = newSprite
        frames = newSprite.writeFrames(images, dither: dither)
        self.updateView()
        self.setDocumentEdited(true)
    }
    
    // MARK: -
    static func filenameExtension(for resourceType: String) -> String {
        return "tiff"
    }
    
    static func export(_ resource: Resource, to url: URL) throws {
        let t = Date.timeIntervalSinceReferenceDate
        guard let spriteType = typeMap[resource.typeCode],
              let data = try spriteType.init(resource.data).readSheet().tiffRepresentation
        else {
            throw SpriteError.unsupported
        }
        try data.write(to: url)
        print(Date.timeIntervalSinceReferenceDate - t)
    }
    
    static func image(for resource: Resource) -> NSImage? {
        guard let spriteType = typeMap[resource.typeCode],
              let frame = try? spriteType.init(resource.data).readFrame()
        else {
            return nil
        }
        let image = NSImage()
        image.addRepresentation(frame)
        return image
    }
}

class AnimationBox: NSBox {
    // Toggle black background on click
    override func mouseDown(with event: NSEvent) {
        self.borderColor = self.borderColor == .gray ? .quaternaryLabelColor : .gray
        self.fillColor = self.fillColor == .black ? .gridColor : .black
    }
}
