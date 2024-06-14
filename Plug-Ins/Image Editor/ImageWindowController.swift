import AppKit
import RFSupport

class ImageWindowController: AbstractEditor, ResourceEditor, PreviewProvider, ExportProvider {
    static let supportedTypes = [
        "PICT",
        "PNG ",
        "PNGf",
        "cicn",
        "ppat",
        "ppt#",
        "crsr",
        "icns",
        "ICON",
        "SICN",
        "ICN#",
        "ics#",
        "icm#",
        "icl4",
        "ics4",
        "icm4",
        "icl8",
        "ics8",
        "icm8",
        "kcs#",
        "kcs4",
        "kcs8",
        "CURS",
        "PAT ",
        "PAT#",
        "pxm#"
    ]

    let resource: Resource
    private let manager: RFEditorManager
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var imageFormat: NSTextField!
    private var format: ImageFormat = .unknown
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!

    override var windowNibName: String {
        return "ImageWindow"
    }

    required init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func windowDidLoad() {
        // Interface builder doesn't allow setting the document view so we have to do it here and configure the constraints
        scrollView.documentView = imageView
        let l = NSLayoutConstraint(item: imageView!, attribute: .leading, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .leading, multiplier: 1, constant: 0)
        let r = NSLayoutConstraint(item: imageView!, attribute: .trailing, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .trailing, multiplier: 1, constant: 0)
        let t = NSLayoutConstraint(item: imageView!, attribute: .top, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .top, multiplier: 1, constant: 0)
        let b = NSLayoutConstraint(item: imageView!, attribute: .bottom, relatedBy: .greaterThanOrEqual, toItem: scrollView, attribute: .bottom, multiplier: 1, constant: 0)
        widthConstraint = NSLayoutConstraint(item: imageView!, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        heightConstraint = NSLayoutConstraint(item: imageView!, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 0)
        scrollView.addConstraints([widthConstraint, heightConstraint, l, r, t, b])
        imageView.allowsCutCopyPaste = false // Ideally want copy/paste but not cut/delete
        switch resource.typeCode {
        case "PICT", "cicn", "ppat", "PNG ", "PNGf":
            imageView.isEditable = true
        default:
            imageView.isEditable = false
        }

        self.loadImage()
    }

    // MARK: -

    private func loadImage() {
        imageView.image = nil
        if let rep = Self.imageRep(for: resource, format: &format) {
            let image = NSImage()
            image.addRepresentation(rep)
            imageView.image = image
            // Colour icons use the mask from the black & white version of the same icon - see if we can load it.
            // Note this is only done within the viewer - preview and export should not access other resources.
            let maskType: String?
            switch resource.typeCode {
            case "icl4", "icl8":
                maskType = "ICN#"
            case "icm4", "icm8":
                maskType = "icm#"
            case "ics4", "ics8":
                maskType = "ics#"
            case "kcs4", "kcs8":
                maskType = "kcs#"
            default:
                maskType = nil
            }
            if let maskType,
               let bw = manager.findResource(type: ResourceType(maskType, resource.typeAttributes), id: resource.id, currentDocumentOnly: true),
               let bwRep = Self.imageRep(for: bw, format: &format) {
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                bwRep.draw(in: image.alignmentRect, from: .zero, operation: .destinationIn, fraction: 1, respectFlipped: true, hints: nil)
            }
        }
        self.updateView()
    }

    private func updateView() {
        imageFormat.stringValue = format.description
        imageFormat.isHidden = imageFormat.stringValue.isEmpty
        if let image = imageView.image {
            widthConstraint.constant = max(image.size.width, window!.contentMinSize.width)
            heightConstraint.constant = max(image.size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSSize(width: widthConstraint.constant, height: heightConstraint.constant))
            imageSize.stringValue = String(format: "%.0fx%.0f", image.size.width, image.size.height)
        } else if !resource.data.isEmpty {
            imageSize.stringValue = "Invalid or unsupported image format"
        } else if imageView.isEditable {
            imageSize.stringValue = "Paste or drag and drop an image to import"
        } else {
            imageSize.stringValue = "Can't edit resources of this type"
        }
    }

    private func ensureBitmap(flatten: Bool=false, palette: Bool=false) {
        let image = imageView.image!
        var rep = image.representations[0] as? NSBitmapImageRep ?? NSBitmapImageRep(data: image.tiffRepresentation!)!
        if flatten {
            ImageFormat.removeTransparency(rep)
        }
        if palette {
            ImageFormat.reduceTo256Colors(&rep)
        }
        // Ensure display size matches pixel dimensions
        rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        // Update the image
        for r in image.representations {
            image.removeRepresentation(r)
        }
        image.addRepresentation(rep)
    }

    // MARK: -

    @IBAction func changedImage(_ sender: Any) {
        switch resource.typeCode {
        case "PICT":
            self.ensureBitmap(flatten: true)
        case "cicn":
            self.ensureBitmap(palette: true)
        case "ppat":
            self.ensureBitmap(flatten: true, palette: true)
        default:
            self.ensureBitmap()
        }
        format = .unknown
        self.updateView()
        self.setDocumentEdited(true)
    }

    @IBAction func saveResource(_ sender: Any) {
        guard let rep = imageView.image?.representations[0] as? NSBitmapImageRep else {
            return
        }
        do {
            switch resource.typeCode {
            case "PICT":
                resource.data = try Picture.data(from: rep, format: &format)
            case "cicn":
                resource.data = try ColorIcon.data(from: rep, format: &format)
            case "ppat":
                resource.data = try PixelPattern.data(from: rep, format: &format)
            default:
                resource.data = rep.representation(using: .png, properties: [.interlaced: false])!
            }
            self.updateView()
            self.setDocumentEdited(false)
        } catch let error {
            self.presentError(error)
        }
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
        guard imageView.isEditable,
              let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage
        else {
            return
        }
        imageView.image = image
        self.changedImage(sender)
    }

    // MARK: - Export Provider

    static func filenameExtension(for resourceType: String) -> String {
        switch resourceType {
        case "PNG ", "PNGf":
            return "png"
        case "icns":
            return "icns"
        default:
            return "tiff"
        }
    }

    static func export(_ resource: Resource, to url: URL) throws {
        let data: Data
        switch resource.typeCode {
        case "PNG ", "PNGf", "icns":
            data = resource.data
        default:
            data = self.image(for: resource)?.tiffRepresentation ?? Data()
        }
        try data.write(to: url)
    }

    // MARK: - Preview Provider

    static func image(for resource: Resource) -> NSImage? {
        var format: ImageFormat = .unknown
        guard let rep = self.imageRep(for: resource, format: &format) else {
            return nil
        }
        let image = NSImage()
        image.addRepresentation(rep)
        return image
    }

    static func maxThumbnailSize(for resourceType: String) -> Int? {
        switch resourceType {
        case "PICT", "PNG ", "PNGf", "pxm#":
            return nil
        default:
            return 64
        }
    }

    private static func imageRep(for resource: Resource, format: inout ImageFormat) -> NSBitmapImageRep? {
        let data = resource.data
        guard !data.isEmpty else {
            return nil
        }
        switch resource.typeCode {
        case "PICT":
            return Picture.rep(data, format: &format)
        case "cicn":
            return ColorIcon.rep(data, format: &format)
        case "ppat":
            return PixelPattern.rep(data, format: &format)
        case "ppt#":
            return PixelPattern.multiRep(data, format: &format)
        case "crsr":
            return ColorCursor.rep(data, format: &format)
        case "ICN#", "ICON":
            return Icons.rep(data, width: 32, height: 32, depth: 1)
        case "ics#", "SICN", "CURS", "kcs#":
            return Icons.rep(data, width: 16, height: 16, depth: 1)
        case "icm#":
            return Icons.rep(data, width: 16, height: 12, depth: 1)
        case "icl4":
            return Icons.rep(data, width: 32, height: 32, depth: 4)
        case "ics4", "kcs4":
            return Icons.rep(data, width: 16, height: 16, depth: 4)
        case "icm4":
            return Icons.rep(data, width: 16, height: 12, depth: 4)
        case "icl8":
            return Icons.rep(data, width: 32, height: 32, depth: 8)
        case "ics8", "kcs8":
            return Icons.rep(data, width: 16, height: 16, depth: 8)
        case "icm8":
            return Icons.rep(data, width: 16, height: 12, depth: 8)
        case "PAT ":
            return Icons.rep(data, width: 8, height: 8, depth: 1)
        case "PAT#":
            return Icons.multiRep(data, width: 8, height: 8, depth: 1)
        case "pxm#":
            return Pxm.rep(data)
        default:
            return NSBitmapImageRep(data: data)
        }
    }
}
