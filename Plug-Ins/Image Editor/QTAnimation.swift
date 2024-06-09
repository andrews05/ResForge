import AppKit
import RFSupport

// https://wiki.multimedia.cx/index.php/Apple_QuickTime_RLE
// Note: Monochrome images have a slightly different encoding from normal that is not documented above.
//  1. The encoding always alternates between skip codes and RLE codes.
//  2. The skip does not have 1 subtracted from it and the high bit is a flag indicating a new line.
//  3. The RLE code 0 indicates frame end rather than another skip.

/// Decoder for the QuickTime "rle " compressor.
struct QTAnimation {
    static func rep(for imageDesc: QTImageDesc, reader: BinaryDataReader) throws -> NSBitmapImageRep {
        // Determine RLE value size in bytes
        let width = Int(imageDesc.width)
        let height = Int(imageDesc.height)
        let depth = imageDesc.resolvedDepth
        let valSize = switch depth {
        case 1, 16: 2
        case 24: 3
        case 2, 4, 8, 32: 4
        default:
            throw ImageReaderError.invalidData
        }

        // Read header and determine lines to skip
        try reader.advance(imageDesc.bytesUntilData + 4) // chunk size
        let header = try reader.read() as UInt16
        var skipLines = 0
        if header & 0x0008 != 0 {
            skipLines = Int(try reader.read() as UInt16)
            guard skipLines < height else {
                throw ImageReaderError.invalidData
            }
            try reader.advance(6)
        }

        // Get the compressed the data
        let rleData = try reader.readData(length: reader.bytesRemaining)
        // Determine row bytes based on width and depth, rounding up to a multiple of 4 to account for any value size
        let rowBytes = (width * depth + 31) / 32 * 4
        // Allocate the output data and decode
        var pixelData = Data(repeating: 0, count: rowBytes * height)
        let startPos = pixelData.startIndex + skipLines * rowBytes
        try pixelData[startPos...].withUnsafeMutableBytes { output in
            try rleData.withUnsafeBytes { input in
                try Self.decodeRle(input, to: output, valSize: valSize, rowBytes: rowBytes, mono: depth == 1)
            }
        }

        // Render the result
        return try imageDesc.blitter(rowBytes: rowBytes).imageRep(pixelData: pixelData, colorTable: imageDesc.colorTable)
    }

    static func decodeRle(_ input: UnsafeRawBufferPointer, to output: UnsafeMutableRawBufferPointer, valSize: Int, rowBytes: Int, mono: Bool) throws {
        var inPos = input.baseAddress!
        var outPos = output.baseAddress!
        let inputEnd = inPos + input.count
        let outputEnd = outPos + output.count
        var linePos = outPos
        skip: while inPos < inputEnd {
            let skip = inPos.load(as: UInt8.self)
            inPos += 1
            if mono {
                if skip >= 0x80 && outPos != linePos {
                    // New line
                    linePos += rowBytes
                    outPos = linePos
                }
                outPos += Int(skip & 0x7F) * valSize
            } else if skip == 0 {
                // Frame end
                break
            } else {
                outPos += Int(skip - 1) * valSize
            }
            while inPos < inputEnd {
                let code = inPos.load(as: Int8.self)
                inPos += 1
                switch code {
                case 0 where mono:
                    // Frame end
                    break skip
                case 0:
                    // Another skip follows
                    continue skip
                case -1:
                    // Next line
                    linePos += rowBytes
                    outPos = linePos
                    continue skip
                case 1...:
                    // Literal - copy bytes
                    let run = Int(code) * valSize
                    guard inPos+run <= inputEnd, outPos+run <= outputEnd else {
                        throw ImageReaderError.invalidData
                    }
                    outPos.copyMemory(from: inPos, byteCount: run)
                    inPos += run
                    outPos += run
                default:
                    // Run - repeat bytes
                    let run = -Int(code)
                    let runEnd = outPos + run * valSize
                    guard inPos+valSize <= inputEnd, runEnd <= outputEnd else {
                        throw ImageReaderError.invalidData
                    }
                    for _ in 0..<run {
                        outPos.copyMemory(from: inPos, byteCount: valSize)
                        outPos += valSize
                    }
                    inPos += valSize
                }
                if mono {
                    break
                }
            }
        }
    }
}
