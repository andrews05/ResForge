import Cocoa

// Implements HBYT, HWRD, HLNG, HLLG
class ElementHBYT<T: FixedWidthInteger & UnsignedInteger>: ElementUBYT<T> {
    override class var formatter: Formatter? {
        return HexFormatter<T>()
    }
}

class HexFormatter<T: FixedWidthInteger & UnsignedInteger>: Formatter {
    private let charCount: Int
    private let invalidChars: CharacterSet
    
    override init() {
        charCount = T.bitWidth/4
        invalidChars = CharacterSet(charactersIn: "0123456789ABCDEFabcdef").inverted
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func string(for obj: Any?) -> String? {
        // Prefix with $ when not editing
        if let obj = obj as? NSNumber {
            let format = String(format: "$%%0%uX", charCount)
            return String(format: format, obj.intValue)
        }
        return nil
    }
    
    override func editingString(for obj: Any) -> String? {
        if let obj = obj as? NSNumber {
            let format = String(format: "%%0%uX", charCount)
            return String(format: format, obj.intValue)
        }
        return nil
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        var string = string
        if string.first == "$" {
            string = String(string.dropFirst())
        }
        var value: UInt64 = 0
        let scanner = Scanner(string: string)
        scanner.scanHexInt64(&value)
        if !scanner.isAtEnd {
            error?.pointee = NSLocalizedString("The value is not a valid hex string.", comment: "") as NSString
            return false
        }
        if value > T.max {
            error?.pointee = NSLocalizedString("The value is too large.", comment: "") as NSString
            return false
        }
        obj?.pointee = value as NSNumber
        return true
    }
    
    override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>,
                                       proposedSelectedRange proposedSelRangePtr: NSRangePointer?,
                                       originalString origString: String,
                                       originalSelectedRange origSelRange: NSRange,
                                       errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        // Reject input with non-hex chars
        let components = partialStringPtr.pointee.components(separatedBy: invalidChars)
        if components.count > 1 {
            partialStringPtr.pointee = origString as NSString
            proposedSelRangePtr?.pointee = origSelRange
            NSSound.beep()
            return false
        }
        if partialStringPtr.pointee.length > charCount {
            // If a range is selected then characters in that range will be removed so adjust the insert length accordingly
            let insertLength = charCount - origString.count + origSelRange.length
            
            // Assemble the string
            let prefix = origString.prefix(origSelRange.location)
            let insert = partialStringPtr.pointee.substring(with: NSMakeRange(origSelRange.location, insertLength))
            let suffix = origString.dropFirst(origSelRange.location + origSelRange.length)
            partialStringPtr.pointee = "\(prefix)\(insert)\(suffix)" as NSString
            
            // Fix-up the proposed selection range
            proposedSelRangePtr?.pointee.location = origSelRange.location + insertLength
            proposedSelRangePtr?.pointee.length = 0
            NSSound.beep()
            return false
        }
        
        return true
    }
}
