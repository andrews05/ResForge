import Cocoa
import RFSupport

// Implements BBIT/BBnn/BFnn, WBIT/WBnn/WFnn, LBIT/LBnn/LFnn
class ElementBBIT<T: FixedWidthInteger & UnsignedInteger>: RangeableElement {
    @objc private var value: UInt = 0
    private var bits = 1
    private var position = 0
    private var bitList: [ElementBBIT] = []
    private var first = true
    
    required init!(type: String, label: String, tooltip: String? = nil) {
        if !type.hasSuffix("BIT") {
            // XXnn - bit field or fill bits
            bits = Int(type.suffix(2))!
            guard bits <= T.bitWidth else {
                return nil
            }
        }
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = type.dropFirst().first != "F"
    }
    
    override func configure() throws {
        if bits == 1 {
            // Single bit, configure like BOOL
            try ElementBOOL.readRadioCases(for: self)
        } else if bits < T.bitWidth {
            // Allow bitfields to configure cases
            try super.configure()
        }
        if !first {
            return
        }
        // Special treatment for BB08/WB16/LB32 (otherwise equivalent to UBYT/UWRD/ULNG): display as rows of checkboxes
        if bits == T.bitWidth {
            for pos in (0..<T.bitWidth).reversed() {
                let bbit = Self.init(type: "BBIT", label: "")!
                bbit.position = pos
                bitList.append(bbit)
            }
            self.rowHeight = Double(bits/8 * 20) + 2
        } else {
            bitList.append(self)
            position = T.bitWidth - bits
            var pos = position
            var i = 0
            while pos > 0 {
                i += 1
                let next = self.parentList.peek(i)
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
    }
    
    override func configure(view: NSView) {
        if bits == 1 {
            ElementBOOL.configureRadios(in: view, for: self)
        } else if bits == T.bitWidth {
            // Display as checkboxes
            var frame = view.frame
            frame.origin.y += 1
            frame.size.width = 20
            frame.size.height = 20
            for i in 0..<bits {
                view.addSubview(ElementBOOL.createCheckbox(with: frame, for: bitList[i]))
                frame.origin.x += 20
                if i % 8 == 7 {
                    frame.origin.x = view.frame.origin.x
                    frame.origin.y += 20
                }
            }
        } else {
            super.configure(view: view)
            if let field = view.subviews.first as? NSTextField {
                field.placeholderString = "\(bits) bits"
            }
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        if first {
            let completeValue: T = try reader.read()
            for bbit in bitList {
                bbit.value = UInt((completeValue >> bbit.position) & ((1 << bbit.bits) - 1))
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
    
    override var formatter: Formatter? {
        if Element.sharedFormatters[type] == nil {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = true
            formatter.minimum = 0
            formatter.maximum = (1 << bits) - 1 as NSNumber
            formatter.nilSymbol = "\0"
            Element.sharedFormatters[type] = formatter
        }
        return Element.sharedFormatters[type]
    }
}
