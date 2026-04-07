import Foundation
import RFSupport

class ElementCHAR: CasedElement {
    @objc private var value: UInt8 = 0

    override func readData(from reader: BinaryDataReader) throws {
        value = try reader.read()
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value)
    }

    override var formatter: Formatter {
        self.sharedFormatter { CharFormatter() }
    }
}

/// Formatter for a single MacRoman character, with support for hex representation of non-printable characters.
class CharFormatter: HexFormatter<UInt8> {
    public override func string(for obj: Any?) -> String? {
        guard let val = obj as? UInt8 else {
            return nil
        }
        switch val {
        case 0:
            return ""
        case 1...31:
            // Non-printable characters should be hex formatted
            return super.string(for: val)
        default:
            // Otherwise render as MacRoman string
            return String(bytes: [val], encoding: .macOSRoman)
        }
    }

    public override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                        for string: String,
                                        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if string.isEmpty {
            obj?.pointee = 0 as AnyObject
            return true
        } else if string.count == 1 {
            guard let char = string.data(using: .macOSRoman)?.first else {
                error?.pointee = "The character is not valid for Mac OS Roman encoding."
                return false
            }
            obj?.pointee = char as AnyObject
            return true
        } else if super.getObjectValue(obj, for: string, errorDescription: nil) {
            return true
        }
        error?.pointee = "The value must be a single character."
        return false
    }
}
