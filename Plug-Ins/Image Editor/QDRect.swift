import AppKit
import RFSupport

struct QDRect {
    var top: Int = 0
    var left: Int = 0
    var bottom: Int
    var right: Int
}

extension QDRect {
    init(_ reader: BinaryDataReader) throws {
        top = Int(try reader.read() as Int16)
        left = Int(try reader.read() as Int16)
        bottom = Int(try reader.read() as Int16)
        right = Int(try reader.read() as Int16)
    }

    init(for rep: NSBitmapImageRep) throws {
        guard rep.pixelsWide <= Int16.max, rep.pixelsHigh <= Int16.max else {
            throw ImageWriterError.tooBig
        }
        bottom = rep.pixelsHigh
        right = rep.pixelsWide
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(Int16(top))
        writer.write(Int16(left))
        writer.write(Int16(bottom))
        writer.write(Int16(right))
    }

    mutating func alignTo(_ point: QDPoint) {
        top -= point.y
        left -= point.x
        bottom -= point.y
        right -= point.x
    }

    func contains(_ other: QDRect) -> Bool {
        other.top >= top &&
        other.left >= left &&
        other.bottom <= bottom &&
        other.right <= right
    }

    func contains(_ point: QDPoint) -> Bool {
        left..<right ~= point.x &&
        top..<bottom ~= point.y
    }

    var origin: QDPoint {
        QDPoint(v: top, h: left)
    }
    var width: Int {
        right - left
    }
    var height: Int {
        bottom - top
    }
    var isValid: Bool {
        bottom > top && right > left
    }

    func nsRect(in rep: NSBitmapImageRep) -> NSRect {
        return NSRect(x: left, y: rep.pixelsHigh - bottom, width: width, height: height)
    }
}

struct QDPoint {
    var v: Int
    var h: Int
}

extension QDPoint {
    init(_ reader: BinaryDataReader) throws {
        v = Int(try reader.read() as Int16)
        h = Int(try reader.read() as Int16)
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(Int16(v))
        writer.write(Int16(h))
    }

    var x: Int {
        get { h }
        set { h = newValue }
    }
    var y: Int {
        get { v }
        set { v = newValue }
    }
}
