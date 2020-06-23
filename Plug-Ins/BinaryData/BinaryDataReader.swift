import Foundation

enum BinaryDataReaderError: Error {
    case notAStruct
	case notEnoughData
}

class BinaryDataReader {
    public var data: Data
    public var bigEndian: Bool
	public var position: Int = 0

    public init(_ data: Data, bigEndian: Bool = true) {
        self.data = data
        self.bigEndian = bigEndian
    }
    
    public func read<T: FixedWidthInteger>(bigEndian: Bool? = nil) throws -> T {
		let bytes = T.bitWidth / 8
		guard position + bytes < data.count else {
			throw BinaryDataReaderError.notEnoughData
		}
		var val: T = 0
        for i in 0..<bytes {
            val += T(data[position]) << (i * 8)
			position += 1
        }
		return bigEndian ?? self.bigEndian ? T(bigEndian: val) : T(littleEndian: val)
    }
}
