import Foundation

public enum BinaryDataReaderError: LocalizedError {
    case insufficientData
    case stringDecodeFailure
    public var errorDescription: String? {
        switch self {
        case .insufficientData:
            return NSLocalizedString("Insufficient data available.", comment: "")
        case .stringDecodeFailure:
            return NSLocalizedString("Unable to decode string in the requested encoding.", comment: "")
        }
    }
}

public class BinaryDataReader {
    public var data: Data
    public var bigEndian: Bool
    private(set) public var position: Int
    public var bytesRead: Int {
        position - data.startIndex
    }
    public var bytesRemaining: Int {
        data.endIndex - position
    }

    private var posStack = [Int]()

    public init(_ data: Data, bigEndian: Bool = true) {
        self.data = data
        self.position = data.startIndex
        self.bigEndian = bigEndian
    }

    @inline(__always)
    public func advance(_ count: Int) throws {
        guard count <= bytesRemaining else {
            throw BinaryDataReaderError.insufficientData
        }
        position += count
    }

    public func setPosition(_ position: Int) throws {
        let position = data.startIndex + position
        guard position <= data.endIndex else {
            throw BinaryDataReaderError.insufficientData
        }
        self.position = position
    }

    public func pushPosition(_ position: Int) throws {
        posStack.append(self.position)
        try self.setPosition(position)
    }

    public func popPosition() {
        assert(!posStack.isEmpty, "position stack is empty")
        self.position = posStack.removeLast()
    }

    public func read<T: FixedWidthInteger>(bigEndian: Bool? = nil) throws -> T {
        let length = T.bitWidth / 8
        try self.advance(length)
        let val = data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: position-length-data.startIndex, as: T.self)
        }
        return bigEndian ?? self.bigEndian ? T(bigEndian: val) : T(littleEndian: val)
    }

    public func readData(length: Int) throws -> Data {
        try self.advance(length)
        return data[(position-length)..<position]
    }

    public func readString(length: Int, encoding: String.Encoding = .utf8) throws -> String {
        guard length != 0 else {
            return ""
        }
        let bytes = try self.readData(length: length)
        guard let string = String(data: bytes, encoding: encoding) else {
            throw BinaryDataReaderError.stringDecodeFailure
        }
        return string
    }

    public func readCString(encoding: String.Encoding = .utf8) throws -> String {
        guard let endIndex = data[position...].firstIndex(of: 0) else {
            throw BinaryDataReaderError.stringDecodeFailure
        }
        guard let string = String(bytes: data[position..<endIndex], encoding: encoding) else {
            throw BinaryDataReaderError.stringDecodeFailure
        }
        position = endIndex + 1
        return string
    }

    // Since Pascal strings are common in resources, this function is included here as a convenience
    public func readPString(encoding: String.Encoding = .macOSRoman) throws -> String {
        let length = Int(try self.read() as UInt8)
        return try self.readString(length: length, encoding: encoding)
    }
}
