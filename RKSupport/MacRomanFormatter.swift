import AppKit

public class MacRomanFormatter: Formatter {
    @objc public var stringLength: Int = 0
    @objc public var valueRequired = false
    @objc public var exactLengthRequired = false
    
    public override func string(for obj: Any?) -> String? {
        return obj as? String
    }
    
    public override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                        for string: String,
                                        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if string.count == 0 {
            if valueRequired && error != nil {
                error?.pointee = NSLocalizedString("The value must be not be blank.", comment: "") as NSString
            }
            return !valueRequired
        }
        if exactLengthRequired && string.count != stringLength {
            if error != nil {
                error?.pointee = String(format: NSLocalizedString("The value must be exactly %d characters.", comment: ""), stringLength) as NSString
            }
            return false
        }
        if !string.canBeConverted(to: .macOSRoman) {
            if error != nil {
                error?.pointee = NSLocalizedString("The value contains invalid characters for Mac OS Roman encoding.", comment: "") as NSString
            }
            return false
        }
        obj?.pointee = string as AnyObject
        return true
    }
    
    public override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>,
                                              proposedSelectedRange proposedSelRangePtr: NSRangePointer?,
                                              originalString origString: String,
                                              originalSelectedRange origSelRange: NSRange,
                                              errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if partialStringPtr.pointee.length > stringLength {
            // If a range is selected then characters in that range will be removed so adjust the length accordingly
            var range = origSelRange
            range.length += stringLength - origString.count

            // Perform the replacement
            let insert = partialStringPtr.pointee.substring(with: range)
            partialStringPtr.pointee = (origString as NSString).replacingCharacters(in: origSelRange, with: insert) as NSString
            
            // Fix-up the proposed selection range
            proposedSelRangePtr?.pointee.location = range.location + range.length
            proposedSelRangePtr?.pointee.length = 0
            NSSound.beep()
            return false
        }
        
        return true
    }
}
