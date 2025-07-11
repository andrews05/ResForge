import Foundation

public enum BinaryDataWriterError: Error {
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

    public func write<T: RawRepresentable>(_ value: T, bigEndian: Bool? = nil) where T.RawValue: FixedWidthInteger {
        self.write(value.rawValue)
    }

    public func write<T: FixedWidthInteger>(_ value: T, at offset: Int, bigEndian: Bool? = nil) {
        let start = data.startIndex + offset
        let end = start + T.bitWidth/8
        let val = bigEndian ?? self.bigEndian ? value.bigEndian : value.littleEndian
        withUnsafeBytes(of: val) {
            data.replaceSubrange(start..<end, with: $0)
        }
    }

    public func writeData(_ newData: Data) {
        data.append(newData)
    }

    public func writeData(_ newData: Data, at offset: Int) {
        let start = data.startIndex + offset
        let end = start + newData.count
        data.replaceSubrange(start..<end, with: newData)
    }

    public func writeString(_ value: String, encoding: String.Encoding = .utf8) throws {
        guard let encoded = value.data(using: encoding) else {
            throw BinaryDataWriterError.stringEncodeFailure
        }
        data.append(encoded)
    }

    public func writeCString(_ value: String, encoding: String.Encoding = .utf8) throws {
        guard let encoded = value.data(using: encoding) else {
            throw BinaryDataWriterError.stringEncodeFailure
        }
        data.append(encoded)
        data.append(0)
    }

    public func writePString(_ value: String, encoding: String.Encoding = .macOSRoman) throws {
        guard let encoded = value.data(using: encoding), encoded.count <= UInt8.max else {
            throw BinaryDataWriterError.stringEncodeFailure
        }
        data.append(UInt8(encoded.count))
        data.append(encoded)
    }

    public func writePString(_ value: String, encoding: String.Encoding = .macOSRoman, fixedSize: Int) throws {
        guard let encoded = value.data(using: encoding), encoded.count <= UInt8.max, encoded.count < fixedSize else {
            throw BinaryDataWriterError.stringEncodeFailure
        }
        data.append(UInt8(encoded.count))
        data.append(encoded)
        self.advance(fixedSize - encoded.count - 1)
    }
}
