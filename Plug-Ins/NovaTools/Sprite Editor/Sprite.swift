import Cocoa

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
    
    func writeSheet(_ image: NSImage, dither: Bool) -> [NSBitmapImageRep]
    
    func writeFrames(_ images: [NSImage], dither: Bool) -> [NSBitmapImageRep]
}
