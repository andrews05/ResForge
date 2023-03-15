import Cocoa
import RFSupport

// Implements BSKP, SKIP, LSKP, BSIZ, WSIZ, LSIZ
class ElementBSKP<T: FixedWidthInteger & UnsignedInteger>: Element, CollectionElement {
    let endType = "SKPE"
    private var subElements: ElementList!
    private var skipLengthBytes: Bool
    private var lengthBytes: Int
    @objc dynamic var value = -1

    required init(type: String, label: String) {
        skipLengthBytes = !type.hasSuffix("SIZ")
        lengthBytes = T.bitWidth / 8
        super.init(type: type, label: label)
    }

    override func configure() throws {
        subElements = try parentList.subList(for: self)
        try subElements.configure()
    }

    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 3
        let textField = NSTextField(frame: frame)
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.bind(.value, to: self, withKeyPath: "value", options: [.valueTransformer: self])
        view.addSubview(textField)
    }

    override func transformedValue(_ value: Any?) -> Any? {
        let value = value as! Int
        if value == -1 {
            return NSLocalizedString("(calculated on save)", comment: "")
        } else {
            return "\(value) " + NSLocalizedString("(recalculated on save)", comment: "")
        }
    }

    override func readData(from reader: BinaryDataReader) throws {
        value = Int(try reader.read() as T)
        var length = value
        if skipLengthBytes {
            guard length >= lengthBytes else {
                throw TemplateError.dataMismatch(self)
            }
            length -= lengthBytes
        }
        // Create a new reader for the skipped section of data
        // This ensures the sub elements cannot read past the end of the section
        let remainder = reader.remainingBytes
        let data: Data
        if length > remainder {
            // Pad to expected length
            data = try reader.readData(length: remainder) + Data(count: length-remainder)
        } else {
            data = try reader.readData(length: length)
        }
        let subReader = BinaryDataReader(data, bigEndian: reader.bigEndian)
        try subElements.readData(from: subReader)
        if length > remainder {
            // Throw the expected error only after reading sub elements
            throw BinaryDataReaderError.insufficientData
        }
    }

    override func writeData(to writer: BinaryDataWriter) {
        var position = writer.position
        writer.advance(lengthBytes)
        if !skipLengthBytes {
            position = writer.position
        }
        subElements.writeData(to: writer)
        // Note: data corruption may occur if the length of the section exceeds the maximum size of the field
        let length = T(clamping: writer.position - position)
        writer.write(length, at: position)
        value = Int(length)
    }

    // MARK: -

    var subElementCount: Int {
        subElements.count
    }

    func subElement(at index: Int) -> Element {
        return subElements.element(at: index)
    }
}
