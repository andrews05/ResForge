import Foundation

public enum BinaryDataWriterError: Error {
    case notAStruct
    case stringEncodeFailure
    case outOfBounds
}

public class BinaryDataWriter {
    public var data: Data
    public var bigEndian: Bool
    public var bytesWritten: Int { data.count }

    public init(capacity: Int = 0, bigEndian: Bool = true) {
        self.data = Data(capacity: capacity)
        self.bigEndian = bigEndian
    }

    public func advance(_ count: Int) {
        data.append(Data(count: count))
    }

    public func write<T: FixedWidthInteger>(_ value: T, bigEndian: Bool? = nil) {
        let val = bigEndian ?? self.bigEndian ? value.bigEndian : value.littleEndian
        withUnsafePointer(to: val) {
            data.append(UnsafeBufferPointer(start: $0, count: 1))
        }
    }

    public func write<T: FixedWidthInteger>(_ value: T, at position: Int, bigEndian: Bool? = nil) {
        let end = position + T.bitWidth/8
        let val = bigEndian ?? self.bigEndian ? value.bigEndian : value.littleEndian
        withUnsafeBytes(of: val) {
            data.replaceSubrange(position..<end, with: $0)
        }
    }

    public func writeString(_ value: String, encoding: String.Encoding = .utf8) throws {
        guard let encoded = value.data(using: encoding) else {
            throw BinaryDataWriterError.stringEncodeFailure
        }
        data.append(encoded)
    }

    public func writeStruct(_ value: Any, bigEndian: Bool? = nil) throws {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle != .struct {
            throw BinaryDataWriterError.notAStruct
        }
        for (_, value) in mirror.children {
            if let value = value as? (any FixedWidthInteger) {
                self.write(value, bigEndian: bigEndian)
            } else {
                try self.writeStruct(value)
            }
        }
    }
}
