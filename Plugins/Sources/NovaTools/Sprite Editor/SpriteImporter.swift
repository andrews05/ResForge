import AppKit

enum SpriteImporterError: LocalizedError {
    case unsupportedFile
    case invalidX(Int)
    case invalidY(Int)
    case noImages
    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return NSLocalizedString("Unsupported file type.", comment: "")
        case .invalidX:
            return NSLocalizedString("Grid X tiles does not fit the image width.", comment: "")
        case .invalidY:
            return NSLocalizedString("Grid Y tiles does not fit the image height.", comment: "")
        case .noImages:
            return NSLocalizedString("No images found in the selected folder.", comment: "")
        }
    }
}

class SpriteImporter: NSObject, NSOpenSavePanelDelegate {
    // Retain grid dimensions for the lifetime of the app
    private static var GRID_X = 6
    private static var GRID_Y = 6
    @IBOutlet weak var optionsView: NSView!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var frameSize: NSTextField!
    @IBOutlet var dither: NSButton!
    @IBOutlet var preview: NSImageView!
    @objc private var gridX = GRID_X {
        didSet {
            Self.GRID_X = gridX
            self.updateGrid()
        }
    }
    @objc private var gridY = GRID_Y {
        didSet {
            Self.GRID_Y = gridY
            self.updateGrid()
        }
    }
    @objc dynamic private var directory = true
    private var image: NSImageRep?
    private var images: [NSImageRep]?

    override init() {
        gridX = Self.GRID_X
        gridY = Self.GRID_Y
        super.init()
    }

    func beginSheetModal(for window: NSWindow,
                         sheetCallback: @escaping(NSImageRep, Int, Int, Bool) -> Void,
                         framesCallback: @escaping([NSImageRep], Bool) -> Void) {
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
                if let image {
                    sheetCallback(image, gridX, gridY, dither.state == .on)
                } else if let images {
                    framesCallback(images, dither.state == .on)
                }
            }
        }
    }

    func beginSheetModal(for window: NSWindow,
                         with image: NSImageRep,
                         sheetCallback: @escaping(NSImageRep, Int, Int, Bool) -> Void) {
        self.setImage(image)
        self.updateGrid()
        // The width of the options view will change when used in the open panel - reset it to an appropriate value
        optionsView.setFrameSize(NSSize(width: 300, height: optionsView.frame.height))
        optionsView.isHidden = false
        let alert = NSAlert()
        alert.accessoryView = optionsView
        if #available(macOS 11, *) {
            // We don't really want an icon but the alert necessarily has one - on macOS 11 we can use the given image
            let icon = NSImage(size: image.size)
            icon.addRepresentation(image)
            alert.icon = icon
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
        optionsView.window?.makeFirstResponder(optionsView.nextValidKeyView)
    }

    func panel(_ sender: Any, validate url: URL) throws {
        if directory {
            var items = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            items.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
            let images = items.compactMap(NSImageRep.init)
            guard !images.isEmpty else {
                throw SpriteImporterError.noImages
            }
            self.images = images
        } else {
            guard let image else {
                throw SpriteImporterError.unsupportedFile
            }
            guard image.pixelsWide.isMultiple(of: gridX) else {
                throw SpriteImporterError.invalidX(gridX)
            }
            guard image.pixelsHigh.isMultiple(of: gridY) else {
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
                self.setImage(NSImageRep(contentsOf: url))
                panel.prompt = NSLocalizedString("Import Image", comment: "")
            }
        }
        self.updateGrid()
    }

    private func updateGrid() {
        guard let image else {
            frameSize.stringValue = "-"
            preview.image = nil
            return
        }
        let width = image.pixelsWide
        let height = image.pixelsHigh
        guard width.isMultiple(of: gridX), height.isMultiple(of: gridY) else {
            frameSize.stringValue = "grid mismatch"
            preview.image = nil
            return
        }
        frameSize.stringValue = "\(width/gridX) x \(height/gridY)"
        let size = NSSize(width: width/gridX, height: height/gridY)
        preview.image = NSImage(size: size, flipped: false) { rect in
            let srcRect = NSRect(x: 0, y: image.size.height-size.height, width: size.width, height: size.height)
            return image.draw(in: rect, from: srcRect, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        }
    }

    private func reset() {
        directory = true
        image = nil
        images = nil
        imageSize.stringValue = "-"
        frameSize.stringValue = "-"
        preview.image = nil
    }

    private func setImage(_ image: NSImageRep?) {
        directory = false
        guard let image,
              image.pixelsWide > 0 && image.pixelsHigh > 0
        else {
            imageSize.stringValue = "unsupported"
            return
        }
        image.size = NSSize(width: image.pixelsWide, height: image.pixelsHigh)
        self.image = image
        imageSize.stringValue = "\(image.pixelsWide) x \(image.pixelsHigh)"
    }
}
