import Cocoa
import RFSupport

class RleX: Sprite {
    var frameWidth = 0
    var frameHeight = 0
    var frameCount = 1
    var data: Data
    
    required init(_ data: Data) throws {
        self.data = data
    }
    
    func readFrame() throws -> NSBitmapImageRep {
        return try self.readSheet()
    }
    
    func readSheet() throws -> NSBitmapImageRep {
        guard let rep = QuickDraw.rep(fromRlex: data) else {
            throw SpriteError.invalid
        }
        frameWidth = rep.pixelsWide
        frameHeight = rep.pixelsHigh
        frameCount = 1
        return rep
    }
}
