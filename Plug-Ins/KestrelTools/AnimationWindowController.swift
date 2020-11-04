import Cocoa
import RKSupport

class AnimationWindowController: NSWindowController, NSMenuItemValidation, ResKnifePlugin {
    static let supportedTypes = ["rlëD"]
    
    let resource: Resource
    private var frames: [NSBitmapImageRep]!
    private var currentFrame = 0
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var imageSize: NSTextField!
    
    override var windowNibName: String {
        return "AnimationWindow"
    }

    required init(resource: Resource) {
        self.resource = resource
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle
        imageView.allowsCutCopyPaste = false // Ideally want copy/paste but not cut/delete
        imageView.isEditable = ["PICT", "cicn", "ppat", "PNG "].contains(resource.type)
    
        self.loadImage()
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
    
    // MARK: -
    
    private func loadImage() {
        imageView.image = nil
        if resource.data.count > 0 {
            do {
                let rle = try Rle(resource.data)
                self.frames = []
                for _ in 0..<rle.frameCount {
                    frames.append(try rle.readFrame())
                }
                imageView.image = NSImage(size: NSMakeSize(CGFloat(rle.frameWidth), CGFloat(rle.frameHeight)))
                currentFrame = -1
                self.nextFrame()
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1/30) { [weak self] in
            self?.nextFrame()
        }
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
