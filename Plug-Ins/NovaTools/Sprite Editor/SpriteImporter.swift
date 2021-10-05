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
            let x = xTiles.integerValue
            guard x > 0, image.representations[0].pixelsWide % x == 0 else {
                throw SpriteImporterError.invalidX(x)
            }
            let y = yTiles.integerValue
            guard y > 0, image.representations[0].pixelsHigh % y == 0 else {
                throw SpriteImporterError.invalidY(y)
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
                directory = false
                if let image = NSImage(contentsOf: url), image.isValid {
                    self.image = image
                    let width = image.representations[0].pixelsWide
                    let height = image.representations[0].pixelsHigh
                    imageSize.stringValue = "\(width) x \(height)"
                    xTiles.isEnabled = true
                    yTiles.isEnabled = true
                } else {
                    imageSize.stringValue = "unsupported"
                }
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
        let x = xTiles.integerValue
        let y = yTiles.integerValue
        guard x > 0, width % x == 0, y > 0, height % y == 0 else {
            frameSize.stringValue = "grid mismatch"
            preview.image = nil
            return
        }
        frameSize.stringValue = "\(width/x) x \(height/y)"
        let size = NSMakeSize(image.size.width/CGFloat(x), image.size.height/CGFloat(y))
        preview.image = NSImage(size: size)
        preview.image?.lockFocus()
        image.draw(at: NSZeroPoint, from: NSMakeRect(0, image.size.height-size.height, size.width, size.height), operation: .copy, fraction: 1)
        preview.image?.unlockFocus()
    }
}
