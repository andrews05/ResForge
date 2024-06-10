import Foundation
import RFSupport

struct PackBits<T: FixedWidthInteger> {
    static func readRows(reader: BinaryDataReader, pixMap: QDPixMap) throws -> Data {
        var pixelData = Data(repeating: 0, count: pixMap.pixelDataSize)
        let rowBytes = pixMap.resolvedRowBytes
        try pixelData.withUnsafeMutableBytes { output in
            var outPos = output.baseAddress!
            for _ in 0..<pixMap.bounds.height {
                // Packed length is a word when rowBytes > 250
                let packLength = if pixMap.rowBytes > 250 {
                    Int(try reader.read() as UInt16)
                } else {
                    Int(try reader.read() as UInt8)
                }
                let packed = try reader.readData(length: packLength)
                try packed.withUnsafeBytes { input in
                    try Self.decode(input, to: outPos, outputSize: rowBytes)
                }
                outPos += rowBytes
            }
        }
        return pixelData
    }

    static func decode(_ input: UnsafeRawBufferPointer, to output: UnsafeMutableRawPointer, outputSize: Int) throws {
        var inPos = input.baseAddress!
        var outPos = output
        let inputEnd = inPos + input.count
        let outputEnd = output + outputSize
        let valSize = T.bitWidth / 8
        while inPos < inputEnd {
            var run = Int(inPos.load(as: UInt8.self))
            inPos += 1
            if run > 0x80 {
                // Repeat single byte
                run = 0x100 - run + 1
                let runEnd = outPos + run * valSize
                guard inPos+valSize <= inputEnd && runEnd <= outputEnd else {
                    throw ImageReaderError.invalid
                }
                let value = inPos.loadUnaligned(as: T.self)
                inPos += valSize
                // Don't bother writing zeros
                if value != 0 {
                    outPos.initializeMemory(as: T.self, repeating: value, count: run)
                }
                outPos = runEnd
            } else if run < 0x80 {
                // Copy bytes
                run = (run + 1) * valSize
                let runEnd = outPos + run
                guard inPos+run <= inputEnd && runEnd <= outputEnd else {
                    throw ImageReaderError.invalid
                }
                outPos.copyMemory(from: inPos, byteCount: run)
                outPos = runEnd
                inPos += run
            }
        }
    }
}
