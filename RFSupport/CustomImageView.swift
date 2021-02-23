import Cocoa

public class CustomImageView: NSImageView {
    // This override ensures crisp rendering of 72-dpi images on retina displays.
    public override func draw(_ dirtyRect: NSRect) {
        if let image = self.image, image.size.width <= dirtyRect.size.width && image.size.height <= dirtyRect.size.height {
            // Setting interpolation of the NSGraphicsContext itself isn't working on macOS 11 - use the cgContext instead
            NSGraphicsContext.current?.cgContext.interpolationQuality = .none
        }
        super.draw(dirtyRect)
        NSGraphicsContext.current?.cgContext.interpolationQuality = .default
    }
}
