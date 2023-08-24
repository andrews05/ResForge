import Foundation
import RFSupport

// https://web.archive.org/web/20180311140826/http://kaiser-edv.de/documents/AppleSingle_AppleDouble.pdf

struct AppleSingleFormat: ResourceFileFormat {
    static let typeName = "com.apple.applesingle-archive"
    let name = NSLocalizedString("AppleSingle Archive", comment: "")
    let supportsResAttributes = true

    static let signature: UInt32 = 0x00051600
    static let version: UInt32 = 0x00020000
    static let fillerBytes = 16
    static let resourceForkID = 2

    private var entries: [(UInt32, Data)] = []

    func filenameExtension(for url: URL?) -> String? {
        // We can't create AppleSingle files, so Save As will default to classic format
        return ClassicFormat.filenameExtension
    }

    mutating func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        var resourcesByType: [ResourceType: [Resource]] = [:]
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
            if entryID == Self.resourceForkID {
                resourcesByType = try ClassicFormat.read(entry)
            } else {
                entries.append((entryID, entry))
            }
            reader.popPosition()
        }

        return resourcesByType
    }

    func write(_ resources: [ResourceType: [Resource]]) throws -> Data {
        let entryDescriptorLength = 12

        // Construct the resource fork
        let rsrcFork = try ClassicFormat.write(resources)

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
        writer.write(UInt32(Self.resourceForkID))
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
