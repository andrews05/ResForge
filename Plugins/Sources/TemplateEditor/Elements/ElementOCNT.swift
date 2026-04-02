import AppKit
import RFSupport

protocol CounterElement where Self: BaseElement {
    var count: Int { get set }
}

// Implements OCNT, ZCNT, BCNT, LCNT, LZCT
class ElementOCNT<T: FixedWidthInteger>: BaseElement, GroupElement, CounterElement {
    private var value: T = 0
    private weak var lstc: ElementLSTB!
    @objc var count: Int {
        get {
            T.isSigned ? Int(value) + 1 : Int(value)
        }
        set {
            value = T.isSigned ? T(newValue - 1) : T(newValue)
        }
    }

    override func configure() throws {
        rowHeight = 16
        lstc = parentList.next(ofType: "LSTC") as? ElementLSTB
        guard lstc != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Following ‘LSTC’ element not found.", comment: ""))
        }
        lstc.counter = self
    }

    func configureGroup(view: NSTableCellView) {
        // Element will show as a group row - we need to combine the counter into the label
        view.textField?.bind(.value, to: self, withKeyPath: "count", options: [.valueTransformer: self])
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return "\(displayLabel) = \(value!)"
    }

    override func readData(from reader: BinaryDataReader) throws {
        lstc.reset()
        value = try reader.read()
        guard count >= 0 else {
            throw TemplateError.dataMismatch(self)
        }
        for _ in 0..<count {
            parentList.insert(lstc.createNext(), before: lstc)
        }
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(value)
    }
}
