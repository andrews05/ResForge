import Cocoa

public class CustomImageView: NSImageView {
    // Somehow this nonsensical override reduces the bluriness of 72-dpi images on retina displays.
    // This will have to do until I can figure out how to fix it properly.
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
}
