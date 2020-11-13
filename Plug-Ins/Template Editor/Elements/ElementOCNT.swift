import Cocoa
import RKSupport

protocol CounterElement where Self: Element {
    var count: Int { get set }
}

// Implements OCNT, ZCNT, BCNT, WCNT, LCNT, LZCT
class ElementOCNT<T: FixedWidthInteger>: Element, GroupElement, CounterElement {
    private var value: T = 0
    private weak var lstc: ElementLSTB!
    @objc var count: Int {
        get {
            Int(value)
        }
        set {
            value = T(newValue)
        }
    }
    
    override func configure() throws {
        self.rowHeight = 18
        lstc = self.parentList.next(ofType: "LSTC") as? ElementLSTB
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
        return "\(self.displayLabel) = \(value!)"
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        if T.isSigned {
            value = try reader.read() + 1
            guard value >= 0 else {
                throw TemplateError.dataMismtach
            }
        } else {
            value = try reader.read()
        }
        for _ in 0..<count {
            self.parentList.insert(lstc.createNext(), before: lstc)
        }
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if T.isSigned {
            writer.write(value - 1)
        } else {
            writer.write(value)
        }
    }
}
