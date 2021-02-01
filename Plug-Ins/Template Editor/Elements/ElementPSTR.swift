import Cocoa
import RKSupport

enum StringPadding {
    case none
    case odd
    case even
    case fixed(_ count: Int)
}
enum StringType {
    case none
    case lengthBytes
    case nullTerminated
}

// Implements PSTR, OSTR, ESTR, BSTR, WSTR, LSTR, CSTR, OCST, ECST, TXTS, Pnnn, Cnnn, Tnnn
class ElementPSTR<T: FixedWidthInteger & UnsignedInteger>: CaseableElement {
    @objc private var value = ""
    private var maxLength = Int(T.max)
    private var padding = StringPadding.none
    private var stringType = StringType.none
    
    override func configure() throws {
        try super.configure()
        switch self.type {
        case "PSTR", "BSTR", "WSTR", "LSTR":
            padding = .none
            stringType = .lengthBytes
        case "OSTR":
            padding = .odd
            stringType = .lengthBytes
        case "ESTR":
            padding = .even
            stringType = .lengthBytes
        case "CSTR":
            padding = .none
            stringType = .nullTerminated
        case "OCST":
            padding = .odd
            stringType = .nullTerminated
        case "ECST":
            padding = .even
            stringType = .nullTerminated
        case "TXTS":
            guard let parent = self.parentList.parentElement, parent.endType == "SKPE" && self.parentList.peek(1) == nil else {
                throw TemplateError.invalidStructure(self, NSLocalizedString("Must be last element in skip offset section.", comment: ""))
            }
            padding = .none
            stringType = .none
        default:
            // Assume Xnnn for anything else
            let nnn = Int(type.suffix(3), radix: 16)!
            // Use resorcerer's more consistent n = datalength rather than resedit's n = stringlength
            padding = .fixed(nnn)
            switch type.first {
            case "P":
                maxLength = min(nnn-1, maxLength)
                stringType = .lengthBytes
            case "C":
                maxLength = nnn-1
                stringType = .nullTerminated
            default:
                maxLength = nnn
                stringType = .none
            }
        }
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
        let outline = self.parentList.controller.dataList!
        let index = outline.row(for: field)
        if index != -1 {
            let element = outline.item(atRow: index) as! Element
            let bounds = NSMakeRect(0, 0, field.bounds.size.width-4, CGFloat.greatestFiniteMagnitude)
            let height = Double(field.cell!.cellSize(forBounds: bounds).height) + 1
            if height != element.rowHeight {
                element.rowHeight = height
                // Notify the outline view
                outline.noteHeightOfRows(withIndexesChanged: [outline.row(for: field)])
            }
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        // Determine string length
        var length: Int
        if stringType != .lengthBytes {
            // Get offset to null
            let end = reader.data[reader.position...].firstIndex(of: 0) ?? reader.data.endIndex
            length = min(end - reader.position, maxLength)
        } else {
            length = Int(try reader.read() as T)
            guard length <= reader.remainingBytes else {
                throw TemplateError.dataMismatch(self)
            }
            // This safety check is currently disabled as it causing problems when reading certain resources where the data must be forced into the template
//            guard length <= maxLength else {
//                throw TemplateError.dataMismatch(self)
//            }
            length = min(length, maxLength)
        }
        
        if length > 0 {
            value = try reader.readString(length: length, encoding: .macOSRoman)
        }
        
        // Advance over empty bytes
        if stringType == .nullTerminated {
            try reader.advance(1)
            length += 1
        } else if stringType == .lengthBytes {
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
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }
        var length = value.count
        if stringType == .lengthBytes {
            writer.write(T(length))
        }
        
        // Error shouldn't happen because the formatter won't allow non-MacRoman characters
        try? writer.writeString(value, encoding: .macOSRoman)
        
        if stringType == .nullTerminated {
            writer.advance(1)
            length += 1
        } else if stringType == .lengthBytes {
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
