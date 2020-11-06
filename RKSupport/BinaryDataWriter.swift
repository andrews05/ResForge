import Foundation

public enum BinaryDataWriterError: Error {
    case notAStruct
    case stringEncodeFailure
    case outOfBounds
}

public class BinaryDataWriter {
    public var data: Data
    public var bigEndian: Bool
    public var position: Int { data.count }

    public init(capacity: Int, bigEndian: Bool = true) {
        self.data = Data(capacity: capacity)
        self.bigEndian = bigEndian
    }
    
    public func advance(_ count: Int) {
        data.append(Data(count: count))
    }
    
    public func write<T: FixedWidthInteger>(_ value: T, bigEndian: Bool? = nil) {
        let val = bigEndian ?? self.bigEndian ? value.bigEndian : value.littleEndian
        withUnsafeBytes(of: val) {
            data.append($0.bindMemory(to: T.self))
        }
    }
    
    public func write<T: FixedWidthInteger>(_ value: T, at position: Int, bigEndian: Bool? = nil) {
        let end = position + T.bitWidth/8
        let val = bigEndian ?? self.bigEndian ? value.bigEndian : value.littleEndian
        withUnsafeBytes(of: val) {
            data.replaceSubrange(position..<end, with: $0)
        }
    }
    
    public func writeRaw<T: FixedWidthInteger>(_ values: [T]) {
        values.withUnsafeBufferPointer {
            data.append($0)
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
            if value is Int8 {
                self.write(value as! Int8, bigEndian: bigEndian)
            } else if value is Int16 {
                self.write(value as! Int16, bigEndian: bigEndian)
            } else if value is Int32 {
                self.write(value as! Int32, bigEndian: bigEndian)
            } else if value is Int64 {
                self.write(value as! Int64, bigEndian: bigEndian)
            } else if value is UInt8 {
                self.write(value as! UInt8, bigEndian: bigEndian)
            } else if value is UInt16 {
                self.write(value as! UInt16, bigEndian: bigEndian)
            } else if value is UInt32 {
                self.write(value as! UInt32, bigEndian: bigEndian)
            } else if value is UInt64 {
                self.write(value as! UInt64, bigEndian: bigEndian)
            } else {
                try self.writeStruct(value)
            }
        }
    }
}
