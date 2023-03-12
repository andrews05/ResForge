import Foundation
import RFSupport

class ElementCHAR: CasedElement {
    private var tValue: UInt8 = 0
    @objc private var value: String {
        get {
            tValue == 0 ? "" : String(bytes: [tValue], encoding: .macOSRoman)!
        }
        set {
            tValue = newValue.data(using: .macOSRoman)?.first ?? 0
        }
    }

    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }

    override var formatter: Formatter {
        self.sharedFormatter { MacRomanFormatter(stringLength: 1, exactLengthRequired: true) }
    }
}
