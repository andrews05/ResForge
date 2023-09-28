import Foundation

// Allow easy translation between String and FourCharCode, in the same manner as classic OSTypes
public extension FourCharCode {
    /// Returns a four character String representation of this integer, using macOSRoman encoding.
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

    /// Creates a new instance from four characters of a String, using macOSRoman encoding.
    init(_ string: String) {
        self = 0
        guard string != "" else {
            return
        }
        var bytes: [UInt8] = [0, 0, 0, 0]
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
        var errorString: NSString?
        guard getObjectValue(&object, for: string, errorDescription: &errorString) else {
            throw CocoaError(.keyValueValidation, userInfo: [NSLocalizedDescriptionKey: errorString as Any])
        }
        return object
    }
}

// Conversions between hexadecimal Strings and Data
public extension String {
    enum ExtendedEncoding {
        case hexadecimal
    }
}

public extension StringProtocol {
    /// Returns a Data containing a representation of the String encoded using a given encoding.
    func data(using encoding: String.ExtendedEncoding) -> Data? {
        guard count % 2 == 0 else { return nil }
        var newData = Data(capacity: count/2)
        for i in stride(from: 0, to: count, by: 2) {
            guard let byte = UInt8(self.dropFirst(i).prefix(2), radix: 16) else {
                return nil
            }
            newData.append(byte)
        }
        return newData
    }
}

public extension Data {
    /// Returns a hexadecimal String representation of the Data.
    var hexadecimal: String {
        return map { String(format: "%02X", $0) }
            .joined()
    }
}
