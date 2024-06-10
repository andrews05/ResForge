import RFSupport

struct QDRect {
    var top: Int16 = 0
    var left: Int16 = 0
    var bottom: Int16
    var right: Int16
}

extension QDRect {
    init(_ reader: BinaryDataReader) throws {
        top = try reader.read()
        left = try reader.read()
        bottom = try reader.read()
        right = try reader.read()
        guard isValid else {
            throw ImageReaderError.invalid
        }
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(top)
        writer.write(left)
        writer.write(bottom)
        writer.write(right)
    }

    mutating func alignTo(_ point: QDPoint) throws {
        top &-= point.y
        left &-= point.x
        bottom &-= point.y
        right &-= point.x
        guard isValid else {
            throw ImageReaderError.invalid
        }
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
        QDPoint(x: left, y: top)
    }
    var width: Int {
        Int(right) - Int(left)
    }
    var height: Int {
        Int(bottom) - Int(top)
    }
    var isValid: Bool {
        bottom >= top && right >= left
    }
}

struct QDPoint {
    var x: Int16
    var y: Int16
}

extension QDPoint {
    init(_ reader: BinaryDataReader) throws {
        x = try reader.read()
        y = try reader.read()
    }

    func write(_ writer: BinaryDataWriter) {
        writer.write(x)
        writer.write(y)
    }
}
