import Foundation
import RFSupport

// https://web.archive.org/web/20180311140826/http://kaiser-edv.de/documents/AppleSingle_AppleDouble.pdf

class AppleSingleFormat: ClassicFormat {
    override var name: String { NSLocalizedString("AppleSingle Archive", comment: "") }

    class var signature: UInt32 { 0x00051600 }
    static let version: UInt32 = 0x00020000
    static let fillerBytes = 16
    static let resourceForkID: UInt32 = 2

    private var entries: [(UInt32, Data)] = []

    override func filenameExtension(for url: URL?) -> String? {
        // We can't create AppleSingle files, so Save As will default to classic format
        return ClassicFormat.defaultExtension
    }

    override func read(_ data: Data) throws -> ResourceMap {
        var resourceMap: ResourceMap = [:]
        let reader = BinaryDataReader(data)

        // Read and validate header
        let signature = try reader.read() as UInt32
        let version = try reader.read() as UInt32
        guard signature == Self.signature,
              version == Self.version
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try reader.advance(Self.fillerBytes)

        // Read the entries
        let numEntries = try reader.read() as UInt16
        for _ in 0..<numEntries {
            let entryID = try reader.read() as UInt32
            let offset = Int(try reader.read() as UInt32)
            let length = Int(try reader.read() as UInt32)

            // Read the entry data
            try reader.pushPosition(offset)
            let entry = try reader.readData(length: length)
            if entryID != Self.resourceForkID {
                entries.append((entryID, entry))
            } else if length > 0 {
                resourceMap = try super.read(entry)
            }
            reader.popPosition()
        }

        return resourceMap
    }

    override func write(_ resourceMap: ResourceMap) throws -> Data {
        let entryDescriptorLength = 12

        // Construct the resource fork
        let rsrcFork = try super.write(resourceMap)

        // Write header
        let writer = BinaryDataWriter()
        writer.write(Self.signature)
        writer.write(Self.version)
        writer.advance(Self.fillerBytes)

        // Write the entry descriptors
        let numEntries = entries.count + 1
        writer.write(UInt16(numEntries))
        var offset = writer.bytesWritten + (numEntries * entryDescriptorLength)
        for (id, entry) in entries {
            writer.write(id)
            writer.write(UInt32(offset))
            writer.write(UInt32(entry.count))
            offset += entry.count
        }
        writer.write(Self.resourceForkID)
        writer.write(UInt32(offset))
        writer.write(UInt32(rsrcFork.count))

        // Write the entry data
        for (_, entry) in entries {
            writer.writeData(entry)
        }
        writer.writeData(rsrcFork)

        return writer.data
    }
}
