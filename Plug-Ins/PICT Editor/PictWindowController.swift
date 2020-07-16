import Cocoa

class PictWindowController: NSWindowController, ResKnifePlugin {
    @objc let resource: ResKnifeResource
    @IBOutlet var imageView: NSImageView!
    @IBOutlet var scrollView: NSScrollView!
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
        self.loadImage()
    }
    
    private func loadImage() {
        if resource.data!.count > 0 {
            switch GetNSStringFromOSType(resource.type) {
            case "PICT":
                imageView.image = NSImage(data: QuickDraw.tiff(fromPict: resource.data!))
            case "cicn":
                imageView.image = NSImage(data: QuickDraw.tiff(fromCicn: resource.data!))
            default:
                imageView.image = NSImage(data: resource.data!)
            }
            self.updateView()
        }
    }
    
    private func updateView() {
        if let image = imageView.image {
            widthConstraint.constant = max(image.size.width, window!.contentMinSize.width)
            heightConstraint.constant = max(image.size.height, window!.contentMinSize.height)
            self.window?.setContentSize(NSMakeSize(widthConstraint.constant, heightConstraint.constant))
        }
    }
    
    @IBAction func changedImage(_ sender: Any) {
        switch GetNSStringFromOSType(resource.type) {
        case "PICT":
            resource.data = QuickDraw.pict(fromTiff: imageView.image!.tiffRepresentation!)
        case "cicn":
            // Perform colour reduction by first converting to gif - this is much faster and better than letting graphite try to do it
            let rep = NSBitmapImageRep(data: imageView.image!.tiffRepresentation!)!
            let gif = rep.representation(using: .gif, properties: [.ditherTransparency: false])!
            imageView.image = NSImage(data: gif)
            resource.data = QuickDraw.cicn(fromTiff: gif)
        default:
            let bitmap = NSBitmapImageRep(data: imageView.image!.tiffRepresentation!)!
            resource.data = bitmap.representation(using: .png, properties: [.interlaced: false])
        }
        self.updateView()
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
}
