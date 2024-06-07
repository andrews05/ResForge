import AppKit
import RFSupport

/// Decoder for the QuickTime "raw " compressor.
struct QTNone {
    static func rep(for imageDesc: QTImageDesc, reader: BinaryDataReader) throws -> NSBitmapImageRep {
        // Determine row bytes based on the data size and height
        let size = Int(imageDesc.dataSize)
        let rowBytes = size / Int(imageDesc.height)

        // Read the data and create the image rep
        try reader.advance(imageDesc.bytesUntilData)
        let data = try reader.readData(length: size)
        return try imageDesc.blitter(rowBytes: rowBytes).imageRep(pixelData: data, colorTable: imageDesc.colorTable)
    }
}
