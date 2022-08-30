import Foundation

// Allow easy translation between String and FourCharCode, in the same manner as classic OSTypes
public extension FourCharCode {
    var stringValue: String {
        guard self != 0 else {
            return ""
        }
        let bytes = [
            UInt8(self >> 24),
            UInt8(self >> 16 & 0xFF),
            UInt8(self >> 8 & 0xFF),
            UInt8(self & 0xFF)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? ""
    }
    init(_ string: String) {
        self = 0
        guard string != "" else {
            return
        }
        var bytes: [UInt8] = [0,0,0,0]
        let max = Swift.min(string.count, 4)
        var used = 0
        var range = string.startIndex..<string.endIndex
        _ = string.getBytes(&bytes, maxLength: max, usedLength: &used, encoding: .macOSRoman, range: range, remaining: &range)
        if used == max {
            self = bytes.reduce(0) { $0 << 8 | Self($1) }
        }
    }
}

// An easier way to get an object value from a Formatter
public extension Formatter {
    func getObjectValue(for string: String) throws -> AnyObject? {
        var object: AnyObject?
        var errorString: NSString? = nil
        guard getObjectValue(&object, for: string, errorDescription: &errorString) else {
            throw CocoaError(.keyValueValidation, userInfo: [NSLocalizedDescriptionKey: errorString as Any])
        }
        return object
    }
}
