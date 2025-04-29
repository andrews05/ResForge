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
class CharFormatter: Formatter {
    private let hexFormatter = HexFormatter<UInt8>()
    private let macRomanFormatter = MacRomanFormatter(stringLength: 1, exactLengthRequired: true)

    public override func string(for obj: Any?) -> String? {
        guard let val = obj as? UInt8 else {
            return nil
        }
        switch val {
        case 0:
            return ""
        case 1...31:
            // Non-printable characters should be hex formatted
            return hexFormatter.string(for: val)
        default:
            // Otherwise render as MacRoman string
            return String(bytes: [val], encoding: .macOSRoman)
        }
    }

    public override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                        for string: String,
                                        errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        do {
            // First try to interpret as MacRoman character
            let char = try macRomanFormatter.getObjectValue(for: string) as? String
            obj?.pointee = (char?.data(using: .macOSRoman)?.first ?? 0) as AnyObject
        } catch let err {
            do {
                // If MacRoman fails, try interpreting as hex
                obj?.pointee = try hexFormatter.getObjectValue(for: string)
            } catch _ {
                // If both fail, return the MacRoman error
                error?.pointee = err.localizedDescription as NSString?
                return false
            }
        }
        return true
    }
}
