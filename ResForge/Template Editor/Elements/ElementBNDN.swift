import Cocoa
import RFSupport

// Implements BNDN, LNDN, BIGE, LTLE
class ElementBNDN: Element, GroupElement {
    private let bigEndian: Bool

    required init(type: String, label: String) {
        bigEndian = type.first == "B"
        super.init(type: type, label: label)
        rowHeight = 16
        visible = !type.hasSuffix("NDN")
    }

    func configureGroup(view: NSTableCellView) {
        view.textField?.stringValue = displayLabel
    }

    override func readData(from reader: BinaryDataReader) throws {
        reader.bigEndian = bigEndian
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.bigEndian = bigEndian
    }
}
