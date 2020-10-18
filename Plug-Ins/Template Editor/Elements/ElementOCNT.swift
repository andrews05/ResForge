import Cocoa
import RKSupport

protocol CounterElement where Self: Element {
    var count: Int { get set }
}

// Implements OCNT, ZCNT, BCNT, WCNT, LCNT, LZCT
class ElementOCNT<T: FixedWidthInteger>: Element, GroupElement, CounterElement {
    private var value: T = 0
    @objc var count: Int {
        get {
            Int(value)
        }
        set {
            value = T(newValue)
        }
    }
    
    required init(type: String, label: String, tooltip: String = "") {
        super.init(type: type, label: label, tooltip: tooltip)
        self.rowHeight = 17
    }
    
    override func configure() throws {
        guard let lstc = self.parentList.next(ofType: "LSTC") as? ElementLSTB else {
            throw TemplateError.invalidStructure("\(type) element not followed by an LSTC element.")
        }
        lstc.counter = self
    }
    
    func configureGroup(view: NSTableCellView) {
        // Element will show as a group row - we need to combine the counter into the label
        view.textField?.bind(NSBindingName("value"), to: self, withKeyPath: "count", options: [.valueTransformer: self])
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return "\(self.displayLabel) = \(value!)"
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        if T.isSigned {
            value = try reader.read() + 1
        } else {
            value = try reader.read()
        }
    }
    
    override func dataSize(_ size: inout Int) {
        size += T.bitWidth / 8
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        if T.isSigned {
            writer.write(value - 1)
        } else {
            writer.write(value)
        }
    }
}
