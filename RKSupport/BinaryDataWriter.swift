import Foundation

public enum BinaryDataWriterError: Error {
    case notAStruct
}

public class BinaryDataWriter {
    public var data: Data
    public var bigEndian: Bool

    public init(capacity: Int, bigEndian: Bool = true) {
        self.data = Data(capacity: capacity)
        self.bigEndian = bigEndian
    }
    
    public func write<T: FixedWidthInteger>(_ value: T, bigEndian: Bool? = nil) {
        let val = bigEndian ?? self.bigEndian ? value.bigEndian : value.littleEndian
        for i in 0..<(val.bitWidth / 8) {
            let byte = UInt8(truncatingIfNeeded: val >> (i * 8))
            data.append(byte)
        }
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
