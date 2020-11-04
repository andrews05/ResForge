import Cocoa
import RKSupport

class AnimationWindowController: NSWindowController, NSMenuItemValidation, ResKnifePlugin {
    static let supportedTypes = ["rlëD"]
    
    let resource: Resource
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
    private var frames: [NSBitmapImageRep]!
    private var currentFrame = 0
    private var timer: Timer?
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var playButton: NSButton!
    @IBOutlet var exportButton: NSButton!
    @IBOutlet var frameCounter: NSTextField!
    
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
        imageView.allowsCutCopyPaste = false // Ideally want copy/paste but not cut/delete
        imageView.isEditable = [].contains(resource.type)
    
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
        case #selector(paste(_:)):
            return imageView.isEditable && NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
        default:
            return true
        }
    }
    
    @IBAction func playPause(_ sender: Any) {
        playing = !playing
    }
    
    @IBAction func exportImage(_ sender: Any) {
        let panel = NSSavePanel()
        if self.resource.name.count > 0 {
            panel.nameFieldStringValue = self.resource.name
        } else {
            panel.nameFieldStringValue = "Frame sheet \(resource.id)"
        }
        panel.allowedFileTypes = ["tiff"]
        panel.beginSheetModal(for: self.window!, completionHandler: { returnCode in
            if returnCode.rawValue == NSFileHandlingPanelOKButton {
                _ = Self.export(self.resource, to: panel.url!)
            }
        })
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
        imageView.image = nil
        playing = false
        frameCounter.stringValue = "-/-"
        playButton.isEnabled = false
        exportButton.isEnabled = false
        if resource.data.count > 0 {
            do {
                let rle = try Rle(resource.data)
                self.frames = []
                for _ in 0..<rle.frameCount {
                    frames.append(try rle.readFrame())
                }
                imageView.image = NSImage(size: NSMakeSize(CGFloat(rle.frameWidth), CGFloat(rle.frameHeight)))
                playButton.isEnabled = true
                exportButton.isEnabled = true
                currentFrame = -1
                playing = true
            } catch {}
        }
        self.updateView()
    }
    
    @objc private func nextFrame() {
        guard let image = imageView.image else {
            return
        }
        currentFrame = (currentFrame + 1) % frames.count
        if image.representations.count > 0 {
            image.removeRepresentation(image.representations[0])
        }
        image.addRepresentation(frames[currentFrame])
        imageView.setNeedsDisplay()
        frameCounter.stringValue = "\(currentFrame+1)/\(frames.count)"
    }
    
    private func updateView() {
        if let image = imageView.image {
            let width = max(image.size.width, window!.contentMinSize.width)
            let height = max(image.size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSMakeSize(width, height))
            imageSize.stringValue = String(format: "%.0fx%.0f", image.size.width, image.size.height)
        } else if resource.data.count > 0 {
            imageSize.stringValue = "Invalid or unsupported data format"
        } else if imageView.isEditable {
            imageSize.stringValue = "Paste or drag and drop an image to import"
        } else {
            imageSize.stringValue = "Can't edit resources of this type"
        }
    }
    
    private func bitmapRep() -> NSBitmapImageRep {
        let image = imageView.image!
        let rep = image.representations[0] as? NSBitmapImageRep ?? NSBitmapImageRep(data: image.tiffRepresentation!)!
        // Update the image
        image.removeRepresentation(image.representations[0])
        image.addRepresentation(rep)
        return rep
    }
    
    // MARK: -
    
    @IBAction func changedImage(_ sender: Any) {
        let rep: NSBitmapImageRep
        switch resource.type {
        default:
            rep = self.bitmapRep()
        }
        _ = rep.bitmapData // Trigger redraw
        self.updateView()
        self.setDocumentEdited(true)
    }

    @IBAction func saveResource(_ sender: Any) {
        guard imageView.image != nil else {
            return
        }
        let rep = self.bitmapRep()
        switch resource.type {
        default:
            resource.data = rep.representation(using: .png, properties: [.interlaced: false])!
        }
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
        guard imageView.isEditable else {
            return
        }
        guard let images = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil) else {
            return
        }
        if images.count > 0 {
            imageView.image = images[0] as? NSImage
            self.changedImage(sender)
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
            // Allow graphite to handle this
            data = QuickDraw.tiff(fromRle: data)
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
        guard resource.data.count > 0 else {
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
