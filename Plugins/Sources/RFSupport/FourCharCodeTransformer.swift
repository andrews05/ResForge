import AppKit

public class FourCharCodeTransformer: ValueTransformer {
    public override func transformedValue(_ value: Any?) -> Any? {
        return (value as? FourCharCode)?.fourCharString
    }

    public override func reverseTransformedValue(_ value: Any?) -> Any? {
        if let value = value as? String {
            return FourCharCode(fourCharString: value)
        }
        return 0
    }

    public override class func allowsReverseTransformation() -> Bool {
        true
    }
}

extension NSValueTransformerName {
    public static let fourCharCodeTransformerName = Self("RFFourCharCodeTransformer")
}
