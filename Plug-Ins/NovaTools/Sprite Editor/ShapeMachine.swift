import Cocoa
import RFSupport

// ShapeMachine IV sprite, as seen in Ares
final class ShapeMachine: Sprite {
    var frameWidth = 0
    var frameHeight = 0
    let frameCount: Int
    private let reader: BinaryDataReader

    var data: Data {
        reader.data
    }

    init(_ data: Data) throws {
        reader = BinaryDataReader(data)
        let size = try reader.read() as UInt32
        guard data.count >= size else {
            throw SpriteError.invalid
        }
        frameCount = Int(try reader.read() as UInt32)
    }

    func readFrame() throws -> NSBitmapImageRep {
        let shape = try self.readShape()
        let frame = self.newFrame(shape.frameWidth, shape.frameHeight)
        let xOffset = shape.frameWidth  / 2 - shape.x
        let yOffset = shape.frameHeight / 2 - shape.y
        let advance = (yOffset * frame.pixelsWide + xOffset) * 4
        try shape.draw(to: frame.bitmapData!+advance, lineAdvance: frame.pixelsWide)
        return frame
    }

    func readSheet() throws -> NSBitmapImageRep {
        try reader.setPosition(8)
        // Read all shapes first so we know the maximum frame size
        let shapes = try (0..<frameCount).map { _ in try self.readShape() }
        let grid = self.sheetGrid()
        let sheet = self.newFrame(frameWidth * grid.x, frameHeight * grid.y)
        let framePointer = sheet.bitmapData!
        for y in 0..<grid.y {
            for x in 0..<grid.x {
                let shape = shapes[y*grid.x + x]
                let xOffset = x * frameWidth  + frameWidth  / 2 - shape.x
                let yOffset = y * frameHeight + frameHeight / 2 - shape.y
                let advance = (yOffset * sheet.pixelsWide + xOffset) * 4
                try shape.draw(to: framePointer+advance, lineAdvance: sheet.pixelsWide)
            }
        }
        return sheet
    }

    private func readShape() throws -> Shape {
        try reader.pushPosition(Int(try reader.read() as UInt32))
        let shape = try Shape(reader: reader)
        try reader.popPosition()
        // Update our max size as necessary
        if shape.frameWidth > frameWidth {
            frameWidth = shape.frameWidth
        }
        if shape.frameHeight > frameHeight {
            frameHeight = shape.frameHeight
        }
        return shape
    }
}

struct Shape {
    let width: Int
    let height: Int
    let x: Int
    let y: Int
    let frameWidth: Int
    let frameHeight: Int
    let data: Data

    init(reader: BinaryDataReader) throws {
        // Read size
        width = Int(try reader.read() as UInt16)
        height = Int(try reader.read() as UInt16)
        guard width > 0, height > 0 else {
            throw SpriteError.invalid
        }
        // Read center point
        x = Int(try reader.read() as Int16)
        y = Int(try reader.read() as Int16)
        // Calculate size of frame when centered on center point
        frameWidth = max(x, width - x) * 2
        frameHeight = max(y, height - y) * 2
        data = try reader.readData(length: width * height)
    }

    func draw(to framePointer: UnsafeMutablePointer<UInt8>, lineAdvance: Int) throws {
        var framePointer = framePointer
        for y in 0..<height {
            for x in 0..<width {
                let pixel = data[data.startIndex + y * width + x]
                let rgb = Self.clut[Int(pixel)]
                framePointer[0] = rgb[0]
                framePointer[1] = rgb[1]
                framePointer[2] = rgb[2]
                framePointer[3] = pixel == 0 ? 0 : 0xFF
                framePointer += 4
            }
            framePointer += (lineAdvance - width) * 4
        }
    }

    // Ares' primary colour table
    static let clut: [[UInt8]] = [
        [255, 255, 255],
        [32, 0, 0],
        [224, 224, 224],
        [208, 208, 208],
        [192, 192, 192],
        [176, 176, 176],
        [160, 160, 160],
        [144, 144, 144],
        [128, 128, 128],
        [112, 112, 112],
        [96, 96, 96],
        [80, 80, 80],
        [64, 64, 64],
        [48, 48, 48],
        [32, 32, 32],
        [16, 16, 16],
        [8, 8, 8],
        [255, 127, 0],
        [240, 120, 0],
        [224, 112, 0],
        [208, 104, 0],
        [192, 96, 0],
        [176, 88, 0],
        [160, 80, 0],
        [144, 72, 0],
        [128, 64, 0],
        [112, 56, 0],
        [96, 48, 0],
        [80, 40, 0],
        [64, 32, 0],
        [48, 24, 0],
        [32, 16, 0],
        [16, 8, 0],
        [255, 255, 0],
        [240, 240, 0],
        [224, 224, 0],
        [208, 208, 0],
        [192, 192, 0],
        [176, 176, 0],
        [160, 160, 0],
        [144, 144, 0],
        [128, 128, 0],
        [112, 112, 0],
        [96, 96, 0],
        [80, 80, 0],
        [64, 64, 0],
        [48, 48, 0],
        [32, 32, 0],
        [16, 16, 0],
        [0, 0, 255],
        [0, 0, 240],
        [0, 0, 224],
        [0, 0, 208],
        [0, 0, 192],
        [0, 0, 176],
        [0, 0, 160],
        [0, 0, 144],
        [0, 0, 128],
        [0, 0, 112],
        [0, 0, 96],
        [0, 0, 80],
        [0, 0, 64],
        [0, 0, 48],
        [0, 0, 32],
        [0, 0, 16],
        [0, 255, 0],
        [0, 240, 0],
        [0, 224, 0],
        [0, 208, 0],
        [0, 192, 0],
        [0, 176, 0],
        [0, 160, 0],
        [0, 144, 0],
        [0, 128, 0],
        [0, 112, 0],
        [0, 96, 0],
        [0, 80, 0],
        [0, 64, 0],
        [0, 48, 0],
        [0, 32, 0],
        [0, 16, 0],
        [127, 0, 255],
        [120, 0, 240],
        [112, 0, 224],
        [104, 0, 208],
        [96, 0, 192],
        [88, 0, 176],
        [80, 0, 160],
        [72, 0, 144],
        [64, 0, 128],
        [56, 0, 112],
        [48, 0, 96],
        [40, 0, 80],
        [32, 0, 64],
        [24, 0, 48],
        [16, 0, 32],
        [8, 0, 16],
        [127, 127, 255],
        [120, 120, 240],
        [112, 112, 224],
        [104, 104, 208],
        [96, 96, 192],
        [88, 88, 176],
        [80, 80, 160],
        [72, 72, 144],
        [64, 64, 128],
        [56, 56, 112],
        [48, 48, 96],
        [40, 40, 80],
        [32, 32, 64],
        [24, 24, 48],
        [16, 16, 32],
        [8, 8, 16],
        [255, 127, 127],
        [240, 120, 120],
        [224, 112, 112],
        [208, 104, 104],
        [192, 96, 96],
        [176, 88, 88],
        [160, 80, 80],
        [144, 72, 72],
        [128, 64, 64],
        [112, 56, 56],
        [96, 48, 48],
        [80, 40, 40],
        [64, 32, 32],
        [48, 24, 24],
        [32, 16, 16],
        [16, 8, 8],
        [255, 255, 127],
        [240, 240, 120],
        [224, 224, 112],
        [208, 208, 104],
        [192, 192, 96],
        [176, 176, 88],
        [160, 160, 80],
        [144, 144, 72],
        [128, 128, 64],
        [112, 112, 56],
        [96, 96, 48],
        [80, 80, 40],
        [64, 64, 32],
        [48, 48, 24],
        [32, 32, 16],
        [16, 16, 8],
        [0, 255, 255],
        [0, 240, 240],
        [0, 224, 224],
        [0, 208, 208],
        [0, 192, 192],
        [0, 176, 176],
        [0, 160, 160],
        [0, 144, 144],
        [0, 128, 128],
        [0, 112, 112],
        [0, 96, 96],
        [0, 80, 80],
        [0, 64, 64],
        [0, 48, 48],
        [0, 32, 32],
        [0, 16, 16],
        [255, 0, 127],
        [240, 0, 120],
        [224, 0, 112],
        [208, 0, 104],
        [192, 0, 96],
        [176, 0, 88],
        [160, 0, 80],
        [144, 0, 72],
        [128, 0, 64],
        [112, 0, 56],
        [96, 0, 48],
        [80, 0, 40],
        [64, 0, 32],
        [48, 0, 24],
        [32, 0, 16],
        [16, 0, 8],
        [127, 255, 127],
        [120, 240, 120],
        [112, 224, 112],
        [104, 208, 104],
        [96, 192, 96],
        [88, 176, 88],
        [80, 160, 80],
        [72, 144, 72],
        [64, 128, 64],
        [56, 112, 56],
        [48, 96, 48],
        [40, 80, 40],
        [32, 64, 32],
        [24, 48, 24],
        [16, 32, 16],
        [8, 16, 8],
        [255, 127, 255],
        [240, 120, 240],
        [224, 112, 224],
        [208, 104, 208],
        [192, 96, 192],
        [176, 88, 176],
        [160, 80, 160],
        [144, 72, 143],
        [128, 64, 128],
        [112, 56, 112],
        [96, 48, 96],
        [80, 40, 80],
        [64, 32, 64],
        [48, 24, 48],
        [32, 16, 32],
        [16, 8, 16],
        [0, 127, 255],
        [0, 120, 240],
        [0, 112, 224],
        [0, 104, 208],
        [0, 96, 192],
        [0, 88, 176],
        [0, 80, 160],
        [0, 72, 143],
        [0, 64, 128],
        [0, 56, 112],
        [0, 48, 96],
        [0, 40, 80],
        [0, 32, 64],
        [0, 24, 48],
        [0, 16, 32],
        [0, 8, 16],
        [255, 249, 207],
        [240, 234, 195],
        [225, 220, 183],
        [210, 205, 171],
        [195, 190, 159],
        [180, 176, 146],
        [165, 161, 134],
        [150, 146, 122],
        [135, 132, 110],
        [120, 117, 97],
        [105, 102, 85],
        [90, 88, 73],
        [75, 73, 61],
        [60, 58, 48],
        [45, 44, 36],
        [30, 29, 24],
        [255, 0, 0],
        [240, 0, 0],
        [225, 0, 0],
        [208, 0, 0],
        [192, 0, 0],
        [176, 0, 0],
        [160, 0, 0],
        [144, 0, 0],
        [128, 0, 0],
        [112, 0, 0],
        [96, 0, 0],
        [80, 0, 0],
        [64, 0, 0],
        [48, 0, 0],
        [0, 0, 0],
    ]
}
