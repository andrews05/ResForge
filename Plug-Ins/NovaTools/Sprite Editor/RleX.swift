import Cocoa
import RFSupport

class RleX: WriteableSprite {
    var frameWidth: Int
    var frameHeight: Int
    var frameCount: Int
    var data: Data
    var frames: [NSBitmapImageRep]
    
    required init(_ data: Data) throws {
        self.data = data
        guard let reps = QuickDraw.reps(fromRlex: data) else {
            throw SpriteError.invalid
        }
        frameWidth = reps[0].pixelsWide
        frameHeight = reps[0].pixelsHigh
        frameCount = reps.count
        frames = reps
    }
    
    required init(width: Int, height: Int, count: Int) {
        frameWidth = width
        frameHeight = height
        frameCount = count
        data = Data()
        frames = []
    }
    
    func readFrame() throws -> NSBitmapImageRep {
        return frames.removeFirst()
    }
    
    func readSheet() throws -> NSBitmapImageRep {
        return NSBitmapImageRep()
    }
    
    func writeSheet(_ image: NSImage, dither: Bool) -> [NSBitmapImageRep] {
        let rep = image.representations[0]
        // Reset the resolution
        rep.size = NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        let gridX = rep.pixelsWide / frameWidth
        var frames: [NSBitmapImageRep] = []
        for i in 0..<frameCount {
            let originX = i % gridX * frameWidth
            let originY = i / gridX * frameHeight
            let frame = self.newFrame()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: frame)
            rep.draw(in: NSRect(x: 0, y: 0, width: frameWidth, height: frameHeight),
                     from: NSRect(x: originX, y: rep.pixelsHigh-originY-frameHeight, width: frameWidth, height: frameHeight),
                     operation: .copy,
                     fraction: 1,
                     respectFlipped: true,
                     hints: nil)
            frames.append(frame)
        }
        data = QuickDraw.rlex(from: frames)
        return frames
    }
    
    private func newFrame() -> NSBitmapImageRep {
        return NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: frameWidth,
                                pixelsHigh: frameHeight,
                                bitsPerSample: 8,
                                samplesPerPixel: 4,
                                hasAlpha: true,
                                isPlanar: false,
                                colorSpaceName: .deviceRGB,
                                bytesPerRow: frameWidth*4,
                                bitsPerPixel: 32)!
    }
    
    func writeFrames(_ images: [NSImage], dither: Bool) -> [NSBitmapImageRep] {
        let reps = images.map { $0.representations[0] as! NSBitmapImageRep }
        data = QuickDraw.rlex(from: reps)
        return reps
    }
}
