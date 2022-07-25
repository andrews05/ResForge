import Cocoa

enum SpriteImporterError: LocalizedError {
    case unsupportedFile
    case invalidX(Int)
    case invalidY(Int)
    case noImages
    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return NSLocalizedString("Unsupported file type.", comment: "")
        case .invalidX(_):
            return NSLocalizedString("Grid X tiles does not fit the image width.", comment: "")
        case .invalidY(_):
            return NSLocalizedString("Grid Y tiles does not fit the image height.", comment: "")
        case .noImages:
            return NSLocalizedString("No images found in the selected folder.", comment: "")
        }
    }
}

class SpriteImporter: NSObject, NSOpenSavePanelDelegate {
    @IBOutlet var optionsView: NSView!
    @IBOutlet var xTiles: NSTextField!
    @IBOutlet var yTiles: NSTextField!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var frameSize: NSTextField!
    @IBOutlet var dither: NSButton!
    @IBOutlet var preview: NSImageView!
    @objc private var gridX = 6 {
        didSet { self.updateGrid(self) }
    }
    @objc private var gridY = 6 {
        didSet { self.updateGrid(self) }
    }
    private var directory = true
    private var image: NSImage?
    private var images: [NSImage]?
    
    func beginSheetModal(for window: NSWindow,
                         sheetCallback: @escaping(NSImage, Int, Int, Bool) -> Void,
                         framesCallback: @escaping([NSImage], Bool) -> Void) {
        self.reset()
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["public.image"]
        panel.canChooseDirectories = true
        panel.delegate = self
        panel.accessoryView = optionsView
        panel.isAccessoryViewDisclosed = true
        panel.prompt = NSLocalizedString("Import Folder", comment: "")
        panel.message = NSLocalizedString("Choose sprite sheet or folder of frames to import", comment: "")
        panel.beginSheetModal(for: window) { [self] modalResponse in
            if modalResponse == .OK {
                if let image = image {
                    sheetCallback(image, xTiles.integerValue, yTiles.integerValue, dither.state == .on)
                } else if let images = images {
                    framesCallback(images, dither.state == .on)
                }
            }
        }
    }
    
    func beginSheetModal(for window: NSWindow,
                         with image: NSImage,
                         sheetCallback: @escaping(NSImage, Int, Int, Bool) -> Void) {
        self.setImage(image)
        self.updateGrid(self)
        // The width of the options view will change when used in the open panel - reset it to an appropriate value
        optionsView.setFrameSize(NSSize(width: 300, height: optionsView.frame.height))
        optionsView.isHidden = false
        let alert = NSAlert()
        alert.accessoryView = optionsView
        if #available(macOS 11, *) {
            // We don't really want an icon but the alert necessarily has one - on macOS 11 we can use the given image
            alert.icon = image
            alert.messageText = ""
        } else {
            // On older systems the default app icon works better but we do need a title
            alert.messageText = NSLocalizedString("Import sprite sheet", comment: "")
        }
        let importButton = alert.addButton(withTitle: NSLocalizedString("Import", comment: ""))
        // The preview image will be nil when the grid is invalid - use this to control the enabled state of the import button
        importButton.bind(.enabled, to: preview!, withKeyPath: "image", options: [.valueTransformerName: NSValueTransformerName.isNotNilTransformerName])
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: window) { [self] modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                sheetCallback(image, gridX, gridY, dither.state == .on)
            }
        }
        optionsView.window?.recalculateKeyViewLoop()
    }
    
    func panel(_ sender: Any, validate url: URL) throws {
        if directory {
            var items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            items.sort(by: { $0.path.localizedStandardCompare($1.path) == .orderedAscending })
            var images: [NSImage] = []
            for item in items {
                if let image = NSImage(contentsOf: item), image.isValid {
                    images.append(image)
                }
            }
            guard !images.isEmpty else {
                throw SpriteImporterError.noImages
            }
            self.images = images
        } else {
            guard let image = image else {
                throw SpriteImporterError.unsupportedFile
            }
            guard gridX > 0, image.representations[0].pixelsWide % gridX == 0 else {
                throw SpriteImporterError.invalidX(gridX)
            }
            guard gridY > 0, image.representations[0].pixelsHigh % gridY == 0 else {
                throw SpriteImporterError.invalidY(gridY)
            }
        }
    }
    
    func panelSelectionDidChange(_ sender: Any?) {
        self.reset()
        let panel = sender as! NSOpenPanel
        if let url = panel.url {
            if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                panel.prompt = NSLocalizedString("Import Folder", comment: "")
            } else {
                self.setImage(NSImage(contentsOf: url))
                panel.prompt = NSLocalizedString("Import Image", comment: "")
            }
        }
        self.updateGrid(self)
    }
    
    @IBAction func updateGrid(_ sender: Any) {
        guard let image = image else {
            frameSize.stringValue = "-"
            preview.image = nil
            return
        }
        let width = image.representations[0].pixelsWide
        let height = image.representations[0].pixelsHigh
        guard gridX > 0, width % gridX == 0, gridY > 0, height % gridY == 0 else {
            frameSize.stringValue = "grid mismatch"
            preview.image = nil
            return
        }
        frameSize.stringValue = "\(width/gridX) x \(height/gridY)"
        let size = NSMakeSize(image.size.width/CGFloat(gridX), image.size.height/CGFloat(gridY))
        preview.image = NSImage(size: size)
        preview.image?.lockFocus()
        image.draw(at: NSZeroPoint, from: NSMakeRect(0, image.size.height-size.height, size.width, size.height), operation: .copy, fraction: 1)
        preview.image?.unlockFocus()
    }
    
    private func reset() {
        directory = true
        image = nil
        images = nil
        imageSize.stringValue = "-"
        xTiles.isEnabled = false
        yTiles.isEnabled = false
        frameSize.stringValue = "-"
        preview.image = nil
    }
    
    private func setImage(_ image: NSImage?) {
        directory = false
        guard let image = image,
              let rep = image.representations.first,
              rep.pixelsWide > 0 && rep.pixelsHigh > 0
        else {
            imageSize.stringValue = "unsupported"
            return
        }
        self.image = image
        imageSize.stringValue = "\(rep.pixelsWide) x \(rep.pixelsHigh)"
        xTiles.isEnabled = true
        yTiles.isEnabled = true
    }
}
