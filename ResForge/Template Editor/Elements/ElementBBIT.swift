import AppKit
import RFSupport

// Implements BBIT/BBnn/BFnn, WBIT/WBnn/WFnn, LBIT/LBnn/LFnn, QBIT/QBnn/QFnn
class ElementBBIT<T: FixedWidthInteger & UnsignedInteger>: RangedElement {
    @objc private var value: UInt = 0
    private var bits = 1
    private var position = 0
    private var bitList: [ElementBBIT] = []
    private var first = true

    required init?(type: String, label: String) {
        if !type.hasSuffix("BIT") {
            // XXnn - bit field or fill bits
            bits = Int(type.suffix(2))!
            guard bits <= T.bitWidth else {
                return nil
            }
        }
        super.init(type: type, label: label)
        visible = type.dropFirst().first != "F"
    }

    override func configure() throws {
        if bits == 1 {
            // Single bit, configure like BOOL
            try ElementBOOL.readCases(for: self)
        } else {
            // Allow bitfields to configure cases
            try super.configure()
        }
        if !first {
            return
        }
        bitList.append(self)
        position = T.bitWidth - bits
        var pos = position
        var i = 0
        while pos > 0 {
            i += 1
            let next = parentList.peek(i)
            // Skip over cosmetic items
            if let next = next, ["CASE", "CASR", "DVDR", "RREF", "PACK"].contains(next.type) {
                continue
            }
            guard let bbit = next as? ElementBBIT else {
                throw TemplateError.invalidStructure(self, NSLocalizedString("Not enough bits in bit field.", comment: ""))
            }
            if bbit.bits > pos {
                throw TemplateError.invalidStructure(bbit, NSLocalizedString("Too many bits in bit field.", comment: ""))
            }
            pos -= bbit.bits
            bbit.position = pos
            bbit.first = false
            bitList.append(bbit)
        }
    }

    override func configure(view: NSView) {
        if bits == 1 {
            ElementBOOL.configure(view: view, for: self)
        } else {
            super.configure(view: view)
            if let field = view.subviews.first as? NSTextField {
                field.placeholderString = "\(bits) bits"
            }
        }
    }

    override func readData(from reader: BinaryDataReader) throws {
        if first {
            let completeValue = UInt(try reader.read() as T)
            for bbit in bitList {
                bbit.value = (completeValue >> bbit.position) & ((1 << bbit.bits) - 1)
            }
        }
    }

    override func writeData(to writer: BinaryDataWriter) {
        if first {
            var completeValue: T = 0
            for bbit in bitList {
                completeValue |= T(bbit.value << bbit.position)
            }
            writer.write(completeValue)
        }
    }

    override var formatter: Formatter {
        self.sharedFormatter("UINT\(bits)") {
            let formatter = NumberFormatter()
            formatter.minimum = 0
            formatter.maximum = (1 << bits) - 1 as NSNumber
            formatter.allowsFloats = false
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
