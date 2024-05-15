import AppKit
import RFSupport

enum StringPadding: Equatable {
    case none
    case c
    case odd
    case oddC
    case even
    case evenC
    case fixed(_ count: Int)

    func length(_ currentLength: Int) -> Int {
        switch self {
        case .none:
            return 0
        case .c:
            return 1
        case .odd:
            return (currentLength+1) % 2
        case .oddC:
            return currentLength % 2 + 1
        case .even:
            return currentLength % 2
        case .evenC:
            return (currentLength+1) % 2 + 1
        case let .fixed(count):
            return count - currentLength
        }
    }
}

// Implements CSTR, OCST, ECST, Cnnn, TXTS, Tnnn
class ElementCSTR: CasedElement {
    @objc var value = ""
    var maxLength = Int(UInt32.max)
    var padding = StringPadding.none
    var insertLineBreaks = false

    override func configure() throws {
        try self.configurePadding()
        try super.configure()
        // Use a width of zero to allow flexible sizing when appropriate
        width = cases.isEmpty && maxLength > 32 ? 0 : 240
        insertLineBreaks = maxLength > 256
    }

    func configurePadding() throws {
        switch type {
        case "CSTR":
            padding = .c
        case "OCST":
            padding = .oddC
        case "ECST":
            padding = .evenC
        case "TXTS":
            guard self.isAtEnd() else {
                throw TemplateError.unboundedElement(self)
            }
            padding = .none
        default:
            // Assume Xnnn for anything else
            let nnn = BaseElement.variableTypeValue(type)
            // Use resorcerer's more consistent n = datalength rather than resedit's n = stringlength
            padding = .fixed(nnn)
            maxLength = type.first == "T" ? nnn : nnn-1
        }
    }

    override func configure(view: NSView) {
        super.configure(view: view)
        let textField = view.subviews.last as! NSTextField
        if maxLength < UInt32.max {
            textField.placeholderString = "\(type) (\(maxLength) characters)"
        }
        if width == 0 {
            textField.lineBreakMode = .byWordWrapping
            DispatchQueue.main.async {
                textField.autoresizingMask = [.width, .height]
                self.autoRowHeight(textField)
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if width == 0, let field = obj.object as? NSTextField {
            self.autoRowHeight(field)
        }
    }

    // Insert new line with return key instead of ending editing (this would otherwise require opt+return)
    override func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if insertLineBreaks && commandSelector == #selector(NSTextView.insertNewline(_:)) {
            textView.insertNewlineIgnoringFieldEditor(nil)
            return true
        }
        return super.control(control, textView: textView, doCommandBy: commandSelector)
    }

    private func autoRowHeight(_ field: NSTextField) {
        guard let outline = parentList?.controller?.dataList else {
            return
        }
        let index = outline.row(for: field)
        if index != -1 {
            let frame = field.cell!.expansionFrame(withFrame: NSRect(x: 0, y: 0, width: field.frame.size.width-4, height: 0), in: field)
            let height = Double(frame.height) + 7
            if height != rowHeight {
                rowHeight = height
                // In case we're not our own row...
                (outline.item(atRow: index) as? BaseElement)?.rowHeight = height
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
        try reader.advance(padding.length(length))
    }

    override func writeData(to writer: BinaryDataWriter) {
        if value.count > maxLength {
            value = String(value.prefix(maxLength))
        }

        // Error shouldn't happen because the formatter won't allow non-MacRoman characters
        try? writer.writeString(value, encoding: .macOSRoman)
        writer.advance(padding.length(value.count))
    }

    override var formatter: Formatter {
        self.sharedFormatter {
            MacRomanFormatter(stringLength: maxLength, convertLineEndings: insertLineBreaks)
        }
    }
}
