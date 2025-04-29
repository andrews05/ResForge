import AppKit

enum SpriteError: Error {
    case invalid
    case unsupported
}

protocol Sprite {
    var frameWidth: Int { get }
    var frameHeight: Int { get }
    var frameCount: Int { get }
    var data: Data { get }

    // Init for reading
    init(_ data: Data) throws

    func readFrame() throws -> NSBitmapImageRep

    func readSheet() throws -> NSBitmapImageRep
}

protocol WriteableSprite: Sprite {
    // Init for writing
    init(width: Int, height: Int, count: Int)

    func writeSheet(_ rep: NSImageRep, dither: Bool) -> [NSBitmapImageRep]

    func writeFrames(_ reps: [NSImageRep], dither: Bool) -> [NSBitmapImageRep]
}

// Utility functions helpful for implementers
extension Sprite {
    func sheetGrid() -> (x: Int, y: Int) {
        var gridX = 6
        if frameCount <= gridX {
            gridX = frameCount
        } else {
            while frameCount % gridX != 0 {
                gridX += 1
            }
        }
        return (gridX, frameCount / gridX)
    }

    func newFrame(_ pixelsWide: Int? = nil, _ pixelsHigh: Int? = nil) -> NSBitmapImageRep {
        return NSBitmapImageRep(bitmapDataPlanes: nil,
                                pixelsWide: pixelsWide ?? frameWidth,
                                pixelsHigh: pixelsHigh ?? frameHeight,
                                bitsPerSample: 8,
                                samplesPerPixel: 4,
                                hasAlpha: true,
                                isPlanar: false,
                                colorSpaceName: .deviceRGB,
                                bytesPerRow: (pixelsWide ?? frameWidth) * 4,
                                bitsPerPixel: 0)!
    }
}
