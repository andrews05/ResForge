import Foundation
import RFSupport

struct PackBits<T: FixedWidthInteger> {
    static func readRows(reader: BinaryDataReader, pixMap: PixelMap) throws -> Data {
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
                // Repeat single value
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

    static func writeRow(_ row: UnsafeMutableBufferPointer<T>, writer: BinaryDataWriter, pixMap: PixelMap) {
        // For best performance we'll use a fixed size output buffer, rather than e.g. incrementally appending to Data
        // In case of incompressible data we need to allocate the whole row size plus a little extra
        let rowBytes = pixMap.rowBytes
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: rowBytes + rowBytes/128 + 1) { outBuffer in
            let output = outBuffer.baseAddress!
            let packLength = Self.encode(row, to: output)
            if rowBytes > 250 {
                writer.write(UInt16(packLength))
            } else {
                writer.write(UInt8(packLength))
            }
            writer.data.append(output, count: packLength)
        }
    }

    static func encode(_ input: UnsafeMutableBufferPointer<T>, to output: UnsafeMutableRawPointer) -> Int {
        var inPos = input.baseAddress!
        var outPos = output
        let valSize = T.bitWidth / 8
        let inputEnd = inPos + input.count - 1
        // For 8-bit we want to avoid breaking a literal to make a run of 2, as it would generally be less efficient
        // For 16-bit we should always use runs where possible
        let inputEnd2 = valSize == 1 ? inputEnd - 1 : inPos
        while inPos <= inputEnd {
            var run = 1
            let runStart = inPos
            let val = inPos[0]
            inPos += 1
            // Repeated run, up to 128
            while run < 0x80 && inPos <= inputEnd && inPos[0] == val {
                run += 1
                inPos += 1
            }

            if run > 1 {
                outPos.storeBytes(of: Int8(-run + 1), as: Int8.self)
                outPos += 1
                outPos.copyMemory(from: runStart, byteCount: valSize)
                outPos += valSize
                continue
            }

            // Literal run, up to 128
            while run < 0x80 && (inPos == inputEnd ||
                                (inPos < inputEnd && inPos[0] != inPos[1]) ||
                                (inPos < inputEnd2 && inPos[0] != inPos[2])) {
                run += 1
                inPos += 1
            }

            outPos.storeBytes(of: Int8(run - 1), as: Int8.self)
            outPos += 1
            outPos.copyMemory(from: runStart, byteCount: run * valSize)
            outPos += run * valSize
        }

        // Return the number of bytes written
        return outPos - output
    }
}
