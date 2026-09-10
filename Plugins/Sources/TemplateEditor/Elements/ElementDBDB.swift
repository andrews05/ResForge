import AppKit
import Foundation
import RFSupport

class ElementDBDB: CasedElement {
    @objc private var first: Double = 0
    @objc private var second: Double = 0

//    required init(type: String, label: String) {
//        super.init(type: type, label: label)
//        blockWidth = 6
//    }

    override func configure(view: NSView) {
        ElementRECT.configure(fields: ["first", "second"], in: view, for: self)
    }

    override func readData(from reader: BinaryDataReader) throws {
        first = Double(bitPattern: try reader.read())
        second = Double(bitPattern: try reader.read())
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(first.bitPattern)
        writer.write(second.bitPattern)
    }

    override var formatter: Formatter {
        self.sharedFormatter {
            let formatter = NumberFormatter()
            formatter.hasThousandSeparators = false
            formatter.numberStyle = .scientific
            formatter.minimum = 0
            formatter.maximum = Double.greatestFiniteMagnitude as NSNumber
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
}
