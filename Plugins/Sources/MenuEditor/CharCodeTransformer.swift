import AppKit

public class CharCodeTransformer: ValueTransformer {
    public override func transformedValue(_ value: Any?) -> Any? {
        if let value = value as? UInt8 {
            return String(bytes: [value], encoding: .macOSRoman)
        }
        return nil
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        return (value as? String)?.data(using: .macOSRoman)?.first ?? 0
    }

    public override class func allowsReverseTransformation() -> Bool {
        true
    }
}

extension NSValueTransformerName {
    public static let charCodeTransformerName = Self("RFCharCodeTransformer")
}
