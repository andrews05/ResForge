import Cocoa
import RFSupport

enum StringPadding {
    case none
    case odd
    case even
    case fixed(_ count: Int)
    
    func length(_ currentLength: Int) -> Int {
        switch self {
        case .none:
            return 0
        case .odd:
            return (currentLength+1) % 2
        case .even:
            return currentLength % 2
        case let .fixed(count):
            return count - currentLength
        }
    }
}

// Implements CSTR, OCST, ECST, Cnnn
class ElementCSTR: CasedElement {
    @objc var value = ""
    var maxLength = Int(UInt32.max)
    var padding = StringPadding.none
    
    required init(type: String, label: String) {
        super.init(type: type, label: label)
        self.configurePadding()
        self.width = 240
    }
    
    override func configure() throws {
        try super.configure()
        if self.cases.isEmpty && maxLength > 32 {
            self.width = 0
        }
    }
    
    func configurePadding() {
        switch type {
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
    
    func controlTextDidChange(_ obj: Notification) {
        if self.width == 0, let field = obj.object as? NSTextField {
            self.autoRowHeight(field)
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
                (outline.item(atRow: index) as? Element)?.rowHeight = height
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
        
        value = try reader.readString(length: length, encoding: .macOSRoman)
        // Advance over null-terminator and any additional padding
        try reader.advance(1 + padding.length(length + 1))
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }
        
        // Error shouldn't happen because the formatter won't allow non-MacRoman characters
        try? writer.writeString(value, encoding: .macOSRoman)
        writer.advance(1 + padding.length(value.count + 1))
    }
    
    override var formatter: Formatter {
        self.sharedFormatter() { MacRomanFormatter(stringLength: maxLength) }
    }
}
