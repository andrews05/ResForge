import AppKit
import RFSupport
import HexFiend

// Implements BHEX, WHEX, LHEX, BSHX, WSHX, LSHX
class ElementBHEX<T: FixedWidthInteger & UnsignedInteger>: ElementHEXD {
    private let lengthBytes = T.bitWidth / 8
    private var maxLength = UInt64(T.max)
    private var skipLengthBytes = false

    override func configure() throws {
        showScroller = T.max > 0xFF
        skipLengthBytes = type.hasSuffix("SHX")
        if skipLengthBytes {
            maxLength -= UInt64(lengthBytes)
        }
        width = 360
    }

    override func hexTextView(_ view: HFTextView, didChangeProperties properties: HFControllerPropertyBits) {
        if properties.contains(.contentLength) && view.byteArray.length() > maxLength {
            // Remove the excess
            // Until we work out how to disable debug in HexFiend, this has to be done async to avoid an assertion failure
            DispatchQueue.main.async { [self] in
                view.controller.insert(Data(), replacingPreviousBytes: view.byteArray.length() - maxLength, allowUndoCoalescing: true)
                NSSound.beep()
            }
        }
        super.hexTextView(view, didChangeProperties: properties)
    }

    override func readData(from reader: BinaryDataReader) throws {
        var length = Int(try reader.read() as T)
        if skipLengthBytes {
            guard length >= lengthBytes else {
                throw TemplateError.dataMismatch(self)
            }
            length -= lengthBytes
        }
        let remainder = reader.bytesRemaining
        if length > remainder {
            // Pad to expected length and throw error
            data = try reader.readData(length: remainder) + Data(count: length-remainder)
            throw BinaryDataReaderError.insufficientData
        } else {
            data = try reader.readData(length: length)
        }
        self.setRowHeight(length)
    }

    override func writeData(to writer: BinaryDataWriter) {
        let data = hexView?.data ?? data
        var writeLength = data.count
        if skipLengthBytes {
            writeLength += lengthBytes
        }
        writer.write(T(writeLength))
        writer.writeData(data)
    }
}
