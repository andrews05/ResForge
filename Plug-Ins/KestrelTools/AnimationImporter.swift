import Cocoa

enum AnimationImporterError: LocalizedError {
    case unsupportedFile
    case invalidX(Int)
    case invalidY(Int)
    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return NSLocalizedString("Unsupported file type.", comment: "")
        case .invalidX(_):
            return NSLocalizedString("Grid X tiles does not fit the image width.", comment: "")
        case .invalidY(_):
            return NSLocalizedString("Grid Y tiles does not fit the image height.", comment: "")
        }
    }
}

class AnimationImporter: NSObject, NSOpenSavePanelDelegate {
    @IBOutlet var optionsView: NSView!
    @IBOutlet var xTiles: NSTextField!
    @IBOutlet var yTiles: NSTextField!
    @IBOutlet var imageSize: NSTextField!
    @IBOutlet var frameSize: NSTextField!
    @IBOutlet var preview: NSImageView!
    private var image: NSImage!
    
    func beginSheetModal(for window: NSWindow, success: @escaping(NSImage, Int, Int) -> Void) {
        imageSize.stringValue = "-"
        frameSize.stringValue = "-"
        image = nil
        preview.image = nil
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["public.image"]
        panel.delegate = self
        panel.accessoryView = optionsView
        panel.isAccessoryViewDisclosed = true
        panel.prompt = NSLocalizedString("Import", comment: "")
        panel.beginSheetModal(for: window) { [self] modalResponse in
            if modalResponse == .OK {
                success(image, xTiles.integerValue, yTiles.integerValue)
            }
        }
    }
    
    func panel(_ sender: Any, validate url: URL) throws {
        guard image.isValid else {
            throw AnimationImporterError.unsupportedFile
        }
        let x = xTiles.integerValue
        guard x > 0, Int(image.size.width) % x == 0 else {
            throw AnimationImporterError.invalidX(x)
        }
        let y = yTiles.integerValue
        guard y > 0, Int(image.size.height) % y == 0 else {
            throw AnimationImporterError.invalidY(y)
        }
    }
    
    func panelSelectionDidChange(_ sender: Any?) {
        if let url = (sender as! NSOpenPanel).url {
            image = NSImage(contentsOf: url)
            if image?.isValid == true {
                let width = image.representations[0].pixelsWide
                let height = image.representations[0].pixelsHigh
                imageSize.stringValue = "\(width) x \(height)"
            } else {
                image = nil
                imageSize.stringValue = "unsupported"
            }
        } else {
            image = nil
            imageSize.stringValue = "-"
        }
        self.updateGrid(self)
    }
    
    @IBAction func updateGrid(_ sender: Any) {
        guard let image = image, image.isValid else {
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
