import Cocoa
import RKSupport

// Implements BSKP, SKIP, LSKP, BSIZ, WSIZ, LSIZ
class ElementBSKP<T: FixedWidthInteger & UnsignedInteger>: Element {
    private var subElements: ElementList!
    private var skipLengthBytes: Bool
    private var lengthBytes: Int
    
    required init!(type: String, label: String, tooltip: String? = nil) {
        skipLengthBytes = !type.hasSuffix("SIZ")
        lengthBytes = T.bitWidth / 8
        super.init(type: type, label: label, tooltip: tooltip)
        self.endType = "SKPE"
    }
    
    override func configure() throws {
        subElements = try self.parentList.subList(for: self)
        try subElements.configure()
    }
    
    override func configure(view: NSView) {
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        var length = Int(try reader.read() as T)
        if skipLengthBytes {
            guard length >= lengthBytes else {
                throw TemplateError.dataMismatch(self)
            }
            length -= lengthBytes
        }
        // Create a new reader for the skipped section of data
        // This ensures the subelements cannot read past the end of the section
        let subData = try reader.readData(length: length)
        let subReader = BinaryDataReader(subData, bigEndian: reader.bigEndian)
        try subElements.readData(from: subReader)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        var position = writer.position
        writer.advance(lengthBytes)
        if !skipLengthBytes {
            position = writer.position
        }
        subElements.writeData(to: writer)
        let length = writer.position - position
        writer.write(T(clamping: length), at: position)
    }

    // MARK: -
    
    override var hasSubElements: Bool {
        true
    }
    
    override var subElementCount: Int {
        subElements.count
    }
    
    override func subElement(at index: Int) -> Element {
        subElements.element(at: index)
    }
}
