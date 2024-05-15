import AppKit

public class CustomImageView: NSImageView {
    // This override ensures crisp rendering of 72-dpi images on retina displays.
    public override func draw(_ dirtyRect: NSRect) {
        if let image = self.image, image.size.width <= dirtyRect.size.width && image.size.height <= dirtyRect.size.height {
            NSGraphicsContext.current?.imageInterpolation = .none
        }
        super.draw(dirtyRect)
    }
}
