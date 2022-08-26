import Cocoa
import RFSupport

// Implements USTR, Unnn
class ElementUSTR: ElementCSTR {
    override func configurePadding() {
        switch type {
        case "USTR":
            padding = .none
        default:
            let nnn = Element.variableTypeValue(type)
            padding = .fixed(nnn)
            maxLength = nnn-1
        }
    }
    
    override func configure(view: NSView) {
        super.configure(view: view)
        if type != "USTR" {
            let textField = view.subviews.last as! NSTextField
            textField.placeholderString = "\(type) (\(maxLength) bytes)"
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let end = reader.data[reader.position...].firstIndex(of: 0) ?? reader.data.endIndex
        let length = min(end - reader.position, maxLength)
        
        do {
            value = try reader.readString(length: length, encoding: .utf8)
        } catch BinaryDataReaderError.stringDecodeFailure {
            throw TemplateError.dataMismatch(self)
        }
        try reader.advance(1 + padding.length(length + 1))
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.utf8.count > maxLength {
            let index = value.utf8.index(value.startIndex, offsetBy: maxLength)
            value = String(value.prefix(upTo: index))
        }
        
        try? writer.writeString(value, encoding: .utf8)
        writer.advance(1 + padding.length(value.utf8.count + 1))
    }
    
    override var formatter: Formatter {
        self.sharedFormatter() { UTF8BytesFormatter(maxBytes: maxLength) }
    }
}

class UTF8BytesFormatter: Formatter {
    var maxBytes = 0
    
    convenience init(maxBytes: Int = 0) {
        self.init()
        self.maxBytes = maxBytes
    }
    
    override func string(for obj: Any?) -> String? {
        return obj as? String
    }
    
    override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?,
                                 for string: String,
                                 errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
        if string.utf8.count > maxBytes {
            error?.pointee = String(format: NSLocalizedString("The value must be no more than %d bytes.", comment: ""), maxBytes) as NSString
            return false
        }
        obj?.pointee = string as AnyObject
        return true
    }
}
