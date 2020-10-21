import Cocoa
import RKSupport

enum StringPadding {
    case none
    case odd
    case even
    case fixed(_ count: Int)
}

// Implements PSTR, OSTR, ESTR, BSTR, WSTR, LSTR, CSTR, OCST, ECST, Pnnn, Cnnn
class ElementPSTR<T: FixedWidthInteger & UnsignedInteger>: CaseableElement {
    @objc private var value: String = ""
    private let maxLength: Int
    private let padding: StringPadding
    private let zeroTerminated: Bool // Indicates Pascal (false) or C string (true)
    
    required init(type: String, label: String, tooltip: String? = nil) {
        var length = Int(T.max)
        switch type {
        case "PSTR", "BSTR", "WSTR", "LSTR":
            padding = .none
            zeroTerminated = false
        case "OSTR":
            padding = .odd
            zeroTerminated = false
        case "ESTR":
            padding = .even
            zeroTerminated = false
        case "CSTR":
            padding = .none
            zeroTerminated = true
        case "OCST":
            padding = .odd
            zeroTerminated = true
        case "ECST":
            padding = .even
            zeroTerminated = true
        default:
            // Assume Xnnn for anything else
            let nnn = Int(type.suffix(3), radix: 16)!
            // Use resorcerer's more consistent n = datalength rather than resedit's n = stringlength
            length = min(nnn-1, length)
            padding = .fixed(nnn)
            zeroTerminated = type.first == "C"
        }
        maxLength = length
        super.init(type: type, label: label, tooltip: tooltip)
    }
    
    override func configure() throws {
        try super.configure()
        self.width = (self.cases == nil && maxLength > 32) ? 0 : 240
    }
    
    override func configure(view: NSView) {
        super.configure(view: view)
        let textField = view.subviews[0] as! NSTextField
        if maxLength < UInt32.max {
            textField.placeholderString = "\(type) (\(maxLength) characters)"
        }
        if self.width == 0 {
            textField.lineBreakMode = .byWordWrapping
            textField.autoresizingMask = [.width, .height]
            DispatchQueue.main.async {
                self.autoRowHeight(textField)
            }
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        if self.width == 0 {
            self.autoRowHeight(obj.object as! NSTextField)
        }
    }
    
    private func autoRowHeight(_ field: NSTextField) {
        let bounds = NSMakeRect(0, 0, field.bounds.size.width-4, CGFloat.greatestFiniteMagnitude)
        let height = Double(field.cell!.cellSize(forBounds: bounds).height) + 1
        if height != self.rowHeight {
            self.rowHeight = height
            // Notify the outline view
            let outline = self.parentList.controller.dataList!
            outline.noteHeightOfRows(withIndexesChanged: [outline.row(for: field)])
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        // Determine string length
        var length: Int
        if zeroTerminated {
            // Get offset to null
            let end = reader.data[reader.position...].firstIndex(of: 0) ?? reader.data.endIndex
            length = end - reader.position
        } else {
            length = Int(try reader.read() as T)
        }
        if length > maxLength {
            length = maxLength
        }
        
        if length > 0 {
            value = try reader.readString(length: length, encoding: .macOSRoman)
        }
        
        // Advance over empty bytes
        if zeroTerminated {
            try reader.advance(1)
            length += 1
        } else {
            length += T.bitWidth / 8
        }
        switch padding {
        case .odd:
            try reader.advance((length+1) % 2)
        case .even:
            try reader.advance(length % 2)
        case let .fixed(count):
            try reader.advance(count - length)
        default:
            break
        }
    }
    
    override func dataSize(_ size: inout Int) {
        if case let .fixed(count) = padding {
            size += count
            return
        }
        var length = min(value.count, maxLength)
        length += zeroTerminated ? 1 : T.bitWidth / 8
        switch padding {
        case .odd:
            length += (length+1) % 2
        case .even:
            length += length % 2
        default:
            break
        }
        size += length
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }
        var length = value.count
        if !zeroTerminated {
            writer.write(T(length))
        }
        
        // Error shouldn't happen because the formatter won't allow non-MacRoman characters
        try? writer.writeString(value, encoding: .macOSRoman)
        
        if zeroTerminated {
            writer.advance(1)
            length += 1
        } else {
            length += T.bitWidth / 8
        }
        switch padding {
        case .odd:
            writer.advance((length+1) % 2)
        case .even:
            writer.advance(length % 2)
        case let .fixed(count):
            writer.advance(count - length)
        default:
            break
        }
    }
    
    override var formatter: Formatter? {
        if Element.sharedFormatters[type] == nil {
            let formatter = MacRomanFormatter()
            formatter.stringLength = maxLength
            Element.sharedFormatters[type] = formatter
        }
        return Element.sharedFormatters[type]
    }
}
