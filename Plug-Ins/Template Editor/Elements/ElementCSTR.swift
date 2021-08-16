import Cocoa
import RFSupport

enum StringPadding {
    case none
    case odd
    case even
    case fixed(_ count: Int)
}

// Implements CSTR, OCST, ECST, Cnnn
class ElementCSTR: CaseableElement {
    @objc var value = ""
    var maxLength = Int(UInt32.max)
    var padding = StringPadding.none
    
    override func configure() throws {
        try super.configure()
        try self.configurePadding()
        self.width = (self.cases == nil && maxLength > 32) ? 0 : 240
    }
    
    func configurePadding() throws {
        switch self.type {
        case "CSTR":
            padding = .none
        case "OCST":
            padding = .odd
        case "ECST":
            padding = .even
        default:
            // Assume Xnnn for anything else
            let nnn = Element.variableTypeValue(type)
            // Use resorcerer's more consistent n = datalength rather than resedit's n = stringlength
            padding = .fixed(nnn)
            maxLength = nnn-1
        }
    }
    
    override func configure(view: NSView) {
        super.configure(view: view)
        let textField = view.subviews.last as! NSTextField
        if maxLength < UInt32.max {
            textField.placeholderString = "\(type) (\(maxLength) characters)"
        }
        if self.width == 0 {
            textField.lineBreakMode = .byWordWrapping
            DispatchQueue.main.async {
                textField.autoresizingMask = [.width, .height]
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
        guard let outline = self.parentList.controller?.dataList else {
            return
        }
        let index = outline.row(for: field)
        if index != -1 {
            let frame = field.cell!.expansionFrame(withFrame: NSMakeRect(0, 0, field.frame.size.width-4, 0), in: field)
            let height = Double(frame.height) + 6
            if height != self.rowHeight {
                self.rowHeight = height
                // In case we're not our own row...
                (outline.item(atRow: index) as! Element).rowHeight = height
                // Notify the outline view without animating
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0
                outline.noteHeightOfRows(withIndexesChanged: [index])
                NSAnimationContext.endGrouping()
            }
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        // Get offset to null
        let end = reader.data[reader.position...].firstIndex(of: 0) ?? reader.data.endIndex
        let length = min(end - reader.position, maxLength)
        
        if length > 0 {
            value = try reader.readString(length: length, encoding: .macOSRoman)
        }
        
        // Advance over null-terminator and any additional padding
        try reader.advance(1)
        try self.readPadding(from: reader, length: length + 1)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }
        
        // Error shouldn't happen because the formatter won't allow non-MacRoman characters
        try? writer.writeString(value, encoding: .macOSRoman)
        
        writer.advance(1)
        self.writePadding(to: writer, length: value.count + 1)
    }
    
    func readPadding(from reader: BinaryDataReader, length: Int) throws {
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
    
    func writePadding(to writer: BinaryDataWriter, length: Int) {
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
