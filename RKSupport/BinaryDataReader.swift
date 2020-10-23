import Foundation

public enum BinaryDataReaderError: Error {
    case notEnoughData
    case stringDecodeFailure
}

public class BinaryDataReader {
    private(set) public var data: Data
    public var bigEndian: Bool
    private(set) public var position: Int

    public init(_ data: Data, bigEndian: Bool = true) {
        self.data = data
        self.position = data.startIndex
        self.bigEndian = bigEndian
    }
    
    public func advance(_ count: Int) throws {
        guard position + count <= data.endIndex else {
            throw BinaryDataReaderError.notEnoughData
        }
        position += count
    }
    
    public func read<T: FixedWidthInteger>(bigEndian: Bool? = nil) throws -> T {
        let bytes = T.bitWidth / 8
        guard position + bytes <= data.endIndex else {
            throw BinaryDataReaderError.notEnoughData
        }
        // Int8 must be constructed from a bit pattern
        if T.self is Int8.Type {
            let val = Int8(bitPattern: data[position]) as! T
            position += 1
            return val
        }
        var val: T = 0
        for i in 0..<bytes {
            val += T(data[position]) << (i * 8)
            position += 1
        }
        return bigEndian ?? self.bigEndian ? T(bigEndian: val) : T(littleEndian: val)
    }
    
    public func readData(length: Int) throws -> Data {
        let end = position + length
        guard end <= data.endIndex else {
            throw BinaryDataReaderError.notEnoughData
        }
        let data = self.data[position..<end]
        position = end
        return data
    }
    
    public func readString(length: Int, encoding: String.Encoding = .utf8) throws -> String {
        let end = position + length
        guard end <= data.endIndex else {
            throw BinaryDataReaderError.notEnoughData
        }
        guard let string = String(data: data[position..<end], encoding: encoding) else {
            throw BinaryDataReaderError.stringDecodeFailure
        }
        position = end
        return string
    }
    
    // Since Pascal strings are common in resources, this function is included here as a convenience
    public func readPString(encoding: String.Encoding = .macOSRoman) throws -> String {
        let length = Int(try self.read() as UInt8)
        return try self.readString(length: length, encoding: encoding)
    }
}
