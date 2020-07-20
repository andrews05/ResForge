import Cocoa

class PictWindowController: NSWindowController, NSWindowDelegate, NSMenuItemValidation, ResKnifePlugin {
    @objc let resource: ResKnifeResource
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var imageSize: NSTextField!
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    
    override var windowNibName: String! {
        return "PictWindow"
    }

    required init(resource: ResKnifeResource) {
        self.resource = resource
        super.init(window: nil)
        
        self.window?.makeKeyAndOrderFront(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle()
        // Interface builder doesn't allow setting the document view so we have to do it here and configure the constraints
        scrollView.documentView = imageView
        let l = NSLayoutConstraint(item: imageView!, attribute: .leading, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .leading, multiplier: 1, constant: 0)
        let r = NSLayoutConstraint(item: imageView!, attribute: .trailing, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .trailing, multiplier: 1, constant: 0)
        let t = NSLayoutConstraint(item: imageView!, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .top, multiplier: 1, constant: 0)
        let b = NSLayoutConstraint(item: imageView!, attribute: .bottom, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .bottom, multiplier: 1, constant: 0)
        widthConstraint = NSLayoutConstraint(item: imageView!, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        heightConstraint = NSLayoutConstraint(item: imageView!, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        scrollView.addConstraints([widthConstraint,heightConstraint,l,r,t,b])
        imageView.allowsCutCopyPaste = false // Ideally want copy/paste but not cut/delete
        imageView.isEditable = ["PICT", "cicn", "ppat", "PNG "].contains(GetNSStringFromOSType(resource.type))
    
        self.loadImage()
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        self.saveResource(sender)
        return true
    }
    
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(saveResource(_:)):
            return self.window!.isDocumentEdited
        case #selector(revertResource(_:)):
            return self.window!.isDocumentEdited
        case #selector(paste(_:)):
            return imageView.isEditable && NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
        default:
            return true
        }
    }
    
    // MARK: -
    
    private func loadImage() {
        imageView.image = PictWindowController.image(for: resource)
        self.updateView()
    }
    
    private func updateView() {
        if let image = imageView.image {
            widthConstraint.constant = max(image.size.width, window!.contentMinSize.width)
            heightConstraint.constant = max(image.size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSMakeSize(widthConstraint.constant, heightConstraint.constant))
            imageSize.stringValue = String(format: "%dx%d", image.representations[0].pixelsWide, image.representations[0].pixelsHigh)
        } else if resource.data!.count > 0 {
            imageSize.stringValue = "Invalid or unsupported image format"
        } else if imageView.isEditable {
            imageSize.stringValue = "Paste or drag and drop an image to import"
        } else {
            imageSize.stringValue = "Can't edit resources of this type"
        }
    }
    
    private func bitmapRep(flatten: Bool=false, palette: Bool=false) -> NSBitmapImageRep {
        let image = imageView.image!
        var rep = image.representations[0] as? NSBitmapImageRep ?? NSBitmapImageRep(data: image.tiffRepresentation!)!
        if palette {
            // Reduce to 8-bit colour by converting to gif
            let data = rep.representation(using: .gif, properties: [.ditherTransparency: false])!
            rep = NSBitmapImageRep(data: data)!
        }
        if flatten {
            // Hide alpha (might be nice to flatten to white background but not really worth the trouble)
            rep.hasAlpha = false
            // Ensure display size matches pixel dimensions
            rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        // Update the image
        image.removeRepresentation(image.representations[0])
        image.addRepresentation(rep)
        return rep
    }
    
    // MARK: -
    
    @IBAction func changedImage(_ sender: Any) {
        let rep: NSBitmapImageRep
        switch GetNSStringFromOSType(resource.type) {
        case "PICT":
            rep = self.bitmapRep(flatten: true)
        case "cicn":
            rep = self.bitmapRep(palette: true)
        case "ppat":
            rep = self.bitmapRep(flatten: true, palette: true)
        default:
            rep = self.bitmapRep()
        }
        _ = rep.bitmapData // Trigger redraw
        self.updateView()
        self.setDocumentEdited(true)
    }

    @IBAction func saveResource(_ sender: Any) {
        guard imageView.image != nil && self.window!.isDocumentEdited else {
            return
        }
        let rep = self.bitmapRep()
        switch GetNSStringFromOSType(resource.type) {
        case "PICT":
            resource.data = QuickDraw.pict(from: rep)
        case "cicn":
            resource.data = QuickDraw.cicn(from: rep)
        case "ppat":
            resource.data = QuickDraw.ppat(from: rep)
        default:
            resource.data = rep.representation(using: .png, properties: [.interlaced: false])
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
    static func filenameExtension(forFileExport: ResKnifeResource) -> String {
        switch GetNSStringFromOSType(forFileExport.type) {
        case "PNG ":
            return "png"
        case "icns":
            return "icns"
        default:
            return "tiff"
        }
    }
    
    static func export(_ resource: ResKnifeResource, to url: URL) {
        do {
            try self.imageData(for: resource).write(to: url)
        } catch let error {
            resource.document().presentError(error)
        }
    }
    
    static func image(for resource: ResKnifeResource!) -> NSImage? {
        return NSImage(data: self.imageData(for: resource))
    }
    
    static func icon(forResourceType resourceType: OSType) -> NSImage! {
        return NSWorkspace.shared.icon(forFileType: "public.image")
    }
    
    private static func imageData(for resource: ResKnifeResource!) -> Data {
        let data = resource.data!
        guard data.count > 0 else {
            return data
        }
        let type = GetNSStringFromOSType(resource.type)
        switch type {
        case "PICT":
            return QuickDraw.tiff(fromPict: data)
        case "cicn":
            return QuickDraw.tiff(fromCicn: data)
        case "ppat":
            return QuickDraw.tiff(fromPpat: data)
        case "ICON":
            return self.iconTiff(data, width: 32, height: 32, alpha: false)
        case "ICN#":
            return self.iconTiff(data, width: 32, height: 32)
        case "ics#":
            return self.iconTiff(data, width: 16, height: 16)
        case "icm#":
            return self.iconTiff(data, width: 16, height: 12)
        case "CURS":
            return self.iconTiff(data, width: 16, height: 16)
        case "PAT ":
            return self.iconTiff(data, width: 8, height: 8, alpha: false)
        default:
            return data
        }
    }
    
    private static func iconTiff(_ data: Data, width: Int, height: Int, alpha: Bool=true) -> Data {
        let bytesPerRow = width / 8
        let planeLength = bytesPerRow * height
        var dataArray: [UInt8] = []
        // Invert data
        for i in 0..<planeLength {
            dataArray.append(data[i] ^ 0xff)
        }

        return dataArray.withUnsafeMutableBufferPointer { (dataBuffer) -> Data in
            var data = [UInt8](data)
            return data.withUnsafeMutableBufferPointer { (maskBuffer) -> Data in
                var planes = [dataBuffer.baseAddress]
                if alpha {
                    planes.append(maskBuffer.baseAddress! + planeLength)
                }
                return NSBitmapImageRep(bitmapDataPlanes: &planes,
                                        pixelsWide: width,
                                        pixelsHigh: height,
                                        bitsPerSample: 1,
                                        samplesPerPixel: alpha ? 2 : 1,
                                        hasAlpha: alpha,
                                        isPlanar: true,
                                        colorSpaceName: .deviceWhite,
                                        bytesPerRow: bytesPerRow,
                                        bitsPerPixel: 1)!.tiffRepresentation!
            }
        }
    }
}
