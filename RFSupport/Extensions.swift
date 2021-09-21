import Foundation

// Allow easy translation between String and FourCharCode
public extension FourCharCode {
    var stringValue: String {
        return UTCreateStringForOSType(self).takeRetainedValue() as String
    }
    init(_ string: String) {
        self = UTGetOSTypeFromString(string as CFString)
    }
}

// An easier way to get an object value from a Formatter
public extension Formatter {
    func getObjectValue(for string: String) throws -> AnyObject? {
        var object: AnyObject?
        var errorString: NSString? = nil
        guard getObjectValue(&object, for: string, errorDescription: &errorString) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSKeyValueValidationError, userInfo: [NSLocalizedDescriptionKey: errorString as Any])
        }
        return object
    }
}
