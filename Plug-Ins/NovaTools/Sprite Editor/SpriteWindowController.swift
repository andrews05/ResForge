import Cocoa
import RFSupport

class SpriteWindowController: AbstractEditor, ResourceEditor, PreviewProvider, ExportProvider {
    static let supportedTypes = ["rlëD"]
    
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
        imageView.needsDisplay = true
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
        importPanel.beginSheetModal(for: self.window!, sheetCallback: self.importSheet, framesCallback: self.importFrames)
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
    
    @IBAction func paste(_ sender: Any) {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            return
        }
        importPanel.beginSheetModal(for: window!, with: image, sheetCallback: self.importSheet)
    }
    
    private func importSheet(image: NSImage, gridX: Int, gridY: Int, dither: Bool) {
        let rep = image.representations[0]
        rle = Rle(width: rep.pixelsWide / gridX, height: rep.pixelsHigh / gridY, count: gridX * gridY)
        frames = rle.writeSheet(image, dither: dither)
        self.updateView()
        self.setDocumentEdited(true)
    }
    
    private func importFrames(images: [NSImage], dither: Bool) {
        let rep = images[0].representations[0]
        rle = Rle(width: rep.pixelsWide, height: rep.pixelsHigh, count: images.count)
        frames = rle.writeFrames(images, dither: dither)
        self.updateView()
        self.setDocumentEdited(true)
    }
    
    // MARK: -
    static func filenameExtension(for resourceType: String) -> String {
        return "tiff"
    }
    
    static func export(_ resource: Resource, to url: URL) throws {
        let data = try Rle(resource.data).readSheet().tiffRepresentation!
        try data.write(to: url)
    }
    
    static func image(for resource: Resource) -> NSImage? {
        guard let frame = try? Rle(resource.data).readFrame() else {
            return nil
        }
        let image = NSImage()
        image.addRepresentation(frame)
        return image
    }
    
    static func previewSize(for resourceType: String) -> Int {
        return 100
    }
}

class AnimationBox: NSBox {
    // Toggle black background on click
    override func mouseDown(with event: NSEvent) {
        self.borderColor = self.borderColor == .gray ? .quaternaryLabelColor : .gray
        self.fillColor = self.fillColor == .black ? .gridColor : .black
    }
}
