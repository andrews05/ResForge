import HexFiend
import RFSupport

// Implements HEXD, HEXS, Hnnn
class ElementHEXD: BaseElement, HFTextViewDelegate {
    private var data = Data()
    private var fixedLength: Int?
    private var hexView: HFTextView?

    override func configure() throws {
        if type == "HEXD" || type == "HEXS" {
            guard self.isAtEnd() else {
                throw TemplateError.unboundedElement(self)
            }
        } else {
            // Hnnn
            let length = BaseElement.variableTypeValue(type)
            fixedLength = length
            data = Data(count: length)
            self.setRowHeight(length)
        }
        width = 360
    }

    override func configure(view: NSView) {
        if let hexView {
            view.addSubview(hexView)
            return
        }
        var frame = view.frame
        frame.origin.y += 2
        frame.size.width = width - 4
        frame.size.height = rowHeight - 4
        let hexView = HFTextView(frame: frame)
        hexView.bordered = true
        hexView.clipsToBounds = true
        hexView.data = data
        hexView.controller.setBytesPerColumn(4)
        // Add line counting view
        let lineCountingRepresenter = HFLineCountingRepresenter()
        lineCountingRepresenter.lineNumberFormat = .hexadecimal
        hexView.layoutRepresenter.addRepresenter(lineCountingRepresenter)
        hexView.controller.addRepresenter(lineCountingRepresenter)
        // Remove ascii view
        for case let stringRep as HFStringEncodingTextRepresenter in hexView.layoutRepresenter.representers {
            hexView.layoutRepresenter.removeRepresenter(stringRep)
            hexView.controller.removeRepresenter(stringRep)
        }
        if fixedLength != nil {
            hexView.controller.editMode = .overwriteMode
            // Remove the vertical scroller as the view is sized to fit
            for case let scroller as HFVerticalScrollerRepresenter in hexView.layoutRepresenter.representers {
                hexView.layoutRepresenter.removeRepresenter(scroller)
                hexView.controller.removeRepresenter(scroller)
            }
        }
        hexView.layoutRepresenter.performLayout()
        hexView.delegate = self
        view.addSubview(hexView)
        // Unlike most elements, we need to retain the view we construct
        self.hexView = hexView
        DispatchQueue.main.async {
            self.autoRowHeight(hexView)
        }
    }

    func hexTextView(_ view: HFTextView, didChangeProperties properties: HFControllerPropertyBits) {
        if properties.contains(.contentValue) {
            parentList.controller.itemValueUpdated(self)
        }
        if properties.contains(.contentLength) && properties.contains(.displayedLineRange) {
            self.autoRowHeight(view)
        }
    }

    private func setRowHeight(_ length: Int, lineHeight: Double = 15) {
        // 24 bytes per line, 15pt line height (minimum height 22)
        // Add 1 as the view creates a new line as soon as one is complete
        let rowBytes = fixedLength == nil ? 20.0 : 24.0
        var lines = ceil(Double(length + 1) / rowBytes)
        if fixedLength == nil {
            lines = min(lines, 30)
        }
        rowHeight = (lines * lineHeight) + 7
    }

    private func autoRowHeight(_ view: HFTextView) {
        let oldHeight = rowHeight
        self.setRowHeight(Int(view.byteArray.length()), lineHeight: view.controller.lineHeight())
        view.frame.size.height = rowHeight - 4
        if rowHeight != oldHeight,
           let outline = parentList?.controller?.dataList,
           case let index = outline.row(for: view),
           index != -1 {
            // Notify the outline view without animating
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = 0
            outline.noteHeightOfRows(withIndexesChanged: [index])
            NSAnimationContext.endGrouping()
        }
    }

    override func readData(from reader: BinaryDataReader) throws {
        if let fixedLength {
            let remainder = reader.bytesRemaining
            if fixedLength > remainder {
                // Pad to expected length and throw error
                data = try reader.readData(length: remainder) + Data(count: fixedLength-remainder)
                throw BinaryDataReaderError.insufficientData
            } else {
                data = try reader.readData(length: fixedLength)
            }
        } else {
            data = try reader.readData(length: reader.bytesRemaining)
        }
        self.setRowHeight(data.count)
    }

    override func writeData(to writer: BinaryDataWriter) {
        let data = hexView?.data ?? data
        assert(fixedLength == nil || data.count == fixedLength)
        writer.writeData(data)
    }
}

extension HFRepresenterHexTextView {
    // HFRepresenterTextView will forward the scroll event to an enclosingScrollView if it exists.
    // We can override it here to only do this if the view itself can't scroll.
    open override func scrollWheel(with event: NSEvent) {
        if let enclosingScrollView,
           let controller = representer().controller(),
           controller.displayedLineRange.length >= Double(controller.totalLineCount()) {
            enclosingScrollView.scrollWheel(with: event)
        } else {
            representer().scrollWheel(event)
        }
    }
}
