import AppKit
import RFSupport

public class ImageEditor: AbstractEditor, ResourceEditor, PreviewProvider, ExportProvider {
    public static var bundle: Bundle { .module }
    public static let supportedTypes = [
        "PICT",
        "PNG ",
        "PNGf",
        "GIFf",
        "jpeg",
        "cicn",
        "ppat",
        "ppt#",
        "crsr",
        "icns",
        "ICON",
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
        "SICN",
        "pxm#"
    ]

    public let resource: Resource
    private let manager: RFEditorManager
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var imageFormat: NSTextField!
    private var format: ImageFormat = .unknown
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    private var formatsMenu: NSMenu?

    public override var windowNibName: NSNib.Name {
        "ImageWindow"
    }

    required public init(resource: Resource, manager: RFEditorManager) {
        self.resource = resource
        self.manager = manager
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func windowDidLoad() {
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

        if resource.typeCode == "PICT" {
            // Set up the format selection menu
            let rgb24 = NSMenuItem(title: "24-bit RGB", action: #selector(self.setFormat(_:)), keyEquivalent: "")
            rgb24.tag = 24
            let rgb16 = NSMenuItem(title: "16-bit RGB", action: #selector(self.setFormat(_:)), keyEquivalent: "")
            rgb16.tag = 16
            let indexed = NSMenuItem(title: "Indexed (best depth)", action: #selector(self.setFormat(_:)), keyEquivalent: "")
            indexed.tag = 8
            let mono = NSMenuItem(title: "Monochrome", action: #selector(self.setFormat(_:)), keyEquivalent: "")
            mono.tag = 1
            let png = NSMenuItem(title: "24-bit PNG", action: #selector(self.setFormat(_:)), keyEquivalent: "")
            png.tag = Int(QTImageDesc.png)
            let jpeg = NSMenuItem(title: "24-bit JPEG", action: #selector(self.setFormat(_:)), keyEquivalent: "")
            jpeg.tag = Int(QTImageDesc.jpeg)
            formatsMenu = NSMenu()
            formatsMenu?.items = [rgb24, rgb16, indexed, mono, png, jpeg]
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
            // Colour icons use the mask from the black & white version of the same icon - see if we can apply it.
            // Note this is only done within the viewer - preview and export should not access other resources.
            Icons.applyMask(for: resource, to: rep, manager: manager)
        }
        self.updateView()
    }

    private func updateView() {
        imageFormat.stringValue = format.description
        imageFormat.isHidden = imageFormat.stringValue.isEmpty
        imageFormat.menu = nil
        if let image = imageView.image {
            widthConstraint.constant = max(image.size.width, window!.contentMinSize.width)
            heightConstraint.constant = max(image.size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSSize(width: widthConstraint.constant, height: heightConstraint.constant))
            imageSize.stringValue = String(format: "%.0fx%.0f", image.size.width, image.size.height)
            if formatsMenu != nil {
                // Add a caret to indicate the menu is available
                let string = NSMutableAttributedString(string: "▼", attributes: [.font: NSFont.systemFont(ofSize: 9)])
                string.append(NSAttributedString(string: " \(imageFormat.stringValue)"))
                imageFormat.attributedStringValue = string
                imageFormat.menu = formatsMenu
            }
        } else if !resource.data.isEmpty {
            imageSize.stringValue = "Invalid or unsupported image format"
        } else if imageView.isEditable {
            imageSize.stringValue = "Paste or drag and drop an image to import"
        } else {
            imageSize.stringValue = "Can't edit resources of this type"
        }
    }

    private func modifyBitmap(_ modify: (inout NSBitmapImageRep) -> ()) {
        guard let image = imageView.image else {
            return
        }
        var rep = image.representations[0] as? NSBitmapImageRep ?? NSBitmapImageRep(data: image.tiffRepresentation!)!
        // Ensure display size matches pixel dimensions
        rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        modify(&rep)
        // Update the image and view
        imageView.image = NSImage()
        imageView.image?.addRepresentation(rep)
        self.updateView()
        self.setDocumentEdited(true)
    }

    // MARK: -

    @IBAction func changedImage(_ sender: Any) {
        self.modifyBitmap { rep in
            switch resource.typeCode {
            case "PICT":
                format = ImageFormat.removeTransparency(rep)
            case "cicn":
                format = ImageFormat.reduceTo256Colors(&rep)
            case "ppat":
                ImageFormat.removeTransparency(rep)
                format = ImageFormat.reduceTo256Colors(&rep)
            default:
                break
            }
        }
    }

    @IBAction public func saveResource(_ sender: Any) {
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

    @IBAction public func revertResource(_ sender: Any) {
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
              let image = NSImage(pasteboard: .general)
        else {
            return
        }
        imageView.image = image
        self.changedImage(sender)
    }

    @IBAction func setFormat(_ sender: NSMenuItem) {
        modifyBitmap { rep in
            ImageFormat.removeTransparency(rep)
            switch sender.tag {
            case 1:
                format = ImageFormat.reduceToMono(&rep)
            case 8:
                format = ImageFormat.reduceTo256Colors(&rep)
            case 16:
                format = ImageFormat.rgb555Dither(rep)
            case 24:
                format = .color(24)
            default:
                format = .quickTime(UInt32(sender.tag), 24)
            }
        }
    }
}

// MARK: - Export Provider
extension ImageEditor {
    public static func filenameExtension(for resourceType: String) -> String {
        switch resourceType {
        case "PNG ", "PNGf":
            return "png"
        case "GIFf":
            return "gif"
        case "jpeg":
            return "jpg"
        case "icns":
            return "icns"
        default:
            return "tiff"
        }
    }

    public static func export(_ resource: Resource, to url: URL) throws {
        let data: Data
        switch resource.typeCode {
        case "PNG ", "PNGf", "GIFf", "jpeg", "icns":
            data = resource.data
        default:
            data = self.image(for: resource)?.tiffRepresentation ?? Data()
        }
        try data.write(to: url)
    }
}

// MARK: - Preview Provider
extension ImageEditor {
    public static func image(for resource: Resource) -> NSImage? {
        var format: ImageFormat = .unknown
        guard let rep = self.imageRep(for: resource, format: &format) else {
            return nil
        }
        let image = NSImage()
        image.addRepresentation(rep)
        return image
    }

    public static func maxThumbnailSize(for resourceType: String) -> Int? {
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
        case "ICN#", "icl4", "icl8", "ics#", "ics4", "ics8", "icm#", "icm4", "icm8",
            "ICON", "SICN", "CURS", "PAT ", "PAT#", "kcs#", "kcs4", "kcs8":
            return Icons.rep(data, for: resource.type)
        case "pxm#":
            return Pxm.rep(data)
        default:
            return NSBitmapImageRep(data: data)
        }
    }
}

class ImageFormatTextField: NSTextField {
    // Show the menu on click
    override func mouseDown(with event: NSEvent) {
        let location = NSPoint(x: frame.minX, y: frame.minY - 6)
        menu?.popUp(positioning: nil, at: location, in: superview)
    }
}
