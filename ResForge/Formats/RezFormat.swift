import Foundation
import RFSupport

// https://github.com/Olde-Skuul/burgerlib/blob/master/source/file/brrezfile.cpp

struct RezFormat: ResourceFileFormat {
    static let typeName = "com.resforge.rez-file"
    let name = NSLocalizedString("Rez File", comment: "")

    static let signature = UInt32(fourCharString: "BRGR")
    static let groupType = 1
    static let mapName = "resource.map"
    static let resourceNameLength = 256

    func read(_ data: Data) throws -> ResourceMap {
        var resourceMap: ResourceMap = [:]
        let reader = BinaryDataReader(data, bigEndian: false)

        // Read and validate header
        let signature = try reader.read(bigEndian: true) as UInt32
        let numGroups = try reader.read() as UInt32
        let headerLength = try reader.read() as UInt32
        let groupType = try reader.read() as UInt32
        let oldFormat = (groupType >> 24) < 32
        if !oldFormat {
            // "New" format, skip compression codecs
            try reader.advance(8)
        }
        let baseIndex = Int(try reader.read() as UInt32)
        let numEntries = Int(try reader.read() as UInt32)
        guard signature == Self.signature,
              numGroups == 1,
              headerLength <= data.count,
              numEntries >= 1
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Read resource offsets
        var offsets: [Int] = []
        var sizes: [Int] = []
        for _ in 0..<numEntries {
            offsets.append(Int(try reader.read() as UInt32))
            sizes.append(Int(try reader.read() as UInt32))
            // Skip name offset (and compressed size) - we'll just assume the resource map is the last entry
            try reader.advance(oldFormat ? 4 : 8)
        }

        // Read map info
        let mapOffset = offsets.last!
        try reader.setPosition(mapOffset)
        reader.bigEndian = true
        let typeListOffset = Int(try reader.read() as UInt32) + mapOffset
        let numTypes = try reader.read() as UInt32

        // Read types
        try reader.setPosition(typeListOffset)
        for _ in 0..<numTypes {
            let type = (try reader.read() as UInt32).fourCharString
            let resourceListOffset = Int(try reader.read() as UInt32) + mapOffset
            let numResources = try reader.read() as UInt32
            let resourceType = ResourceType(type)

            // Read resources
            try reader.pushPosition(resourceListOffset)
            var resources: [Resource] = []
            for _ in 0..<numResources {
                let index = Int(try reader.read() as UInt32) - baseIndex
                guard 0..<numEntries ~= index else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try reader.advance(4) // Skip type, which we already know
                let id = Int(try reader.read() as Int16)
                let nextOffset = reader.bytesRead + Self.resourceNameLength

                // Read resource name
                let name = try reader.readCString(encoding: .macOSRoman)

                // Read resource data
                try reader.setPosition(offsets[index])
                let data = try reader.readData(length: sizes[index])
                try reader.setPosition(nextOffset)

                // Construct resource
                let resource = Resource(type: resourceType, id: id, name: name, data: data)
                resources.append(resource)
            }
            resourceMap[resourceType] = resources
            reader.popPosition()
        }

        return resourceMap
    }

    func write(_ resourceMap: ResourceMap) throws -> Data {
        // Known constants
        let numGroups = 1
        let maxOldOffset = 1 << 29 // In old format, upper 3 offset bits are flags
        let mapHeaderLength = 8
        let typeInfoLength = 12
        let resourceInfoLength = 10 + Self.resourceNameLength

        // Perform some initial calculations
        let numTypes = resourceMap.count
        let numResources = resourceMap.values.map(\.count).reduce(0, +)
        let numEntries = numResources + 1 // Resource map is the last entry
        let totalResourceSize = resourceMap.values.reduce(0) { size, resources in
            size + resources.reduce(0) { $0 + $1.data.count }
        }

        // Start with the old format
        var rootHeaderLength = 12
        var groupHeaderLength = 12
        var resourceOffsetLength = 12
        var nameListOffset = groupHeaderLength + (numEntries * resourceOffsetLength)
        var headerLength = nameListOffset + Self.mapName.count + 1
        // If offsets would be too big for the old format then switch to new format
        // (Note we don't account for deduplication here)
        let oldFormat = (rootHeaderLength + headerLength + totalResourceSize) < maxOldOffset
        if !oldFormat {
            rootHeaderLength = 24
            groupHeaderLength = 8
            resourceOffsetLength = 16
            nameListOffset = groupHeaderLength + (numEntries * resourceOffsetLength)
            headerLength = nameListOffset + Self.mapName.count + 1
        }
        var index = 1 // Base index

        let writer = BinaryDataWriter(bigEndian: false)

        // Write root header
        writer.write(Self.signature, bigEndian: true)
        writer.write(UInt32(numGroups))
        writer.write(UInt32(headerLength))
        if !oldFormat {
            // Unsure exactly what should go in the codecs, but it can't just be 0 or else it will
            // be interpreted as the old format
            let noneCodec = UInt32(fourCharString: "none")
            writer.write(noneCodec, bigEndian: true)
            writer.write(noneCodec, bigEndian: true)
            writer.write(noneCodec, bigEndian: true)
        }
        assert(writer.bytesWritten == rootHeaderLength)

        // Write group header
        if oldFormat {
            writer.write(UInt32(Self.groupType))
        }
        writer.write(UInt32(index))
        writer.write(UInt32(numEntries))
        assert(writer.bytesWritten == rootHeaderLength + groupHeaderLength)

        // Write offsets, deduplicating the data where possible
        var resourceDataOffset = rootHeaderLength + headerLength
        var dataOffsets: [Data: Int] = [:]
        var resourcesToWrite: [Resource] = []
        for (type, resources) in resourceMap {
            guard type.attributes.isEmpty else {
                throw ResourceFormatError.typeAttributesNotSupported
            }
            for resource in resources {
                guard self.isValid(id: resource.id) else {
                    throw ResourceFormatError.invalidID(resource.id)
                }
                // Use inout closure to get or store the default in the dictionary with only one lookup
                let offset = {$0}(&dataOffsets[resource.data, default: resourceDataOffset])
                writer.write(UInt32(offset))
                writer.write(UInt32(resource.data.count))
                // Skip name offset (and compressed size)
                writer.advance(oldFormat ? 4 : 8)
                if offset == resourceDataOffset {
                    resourceDataOffset += resource.data.count
                    resourcesToWrite.append(resource)
                }
            }
        }

        // Write map offsets
        assert(!oldFormat || resourceDataOffset < maxOldOffset)
        var resourceListOffset = mapHeaderLength + (numTypes * typeInfoLength)
        let mapLength = resourceListOffset + (numResources * resourceInfoLength)
        writer.write(UInt32(resourceDataOffset))
        writer.write(UInt32(mapLength))
        writer.write(UInt32(nameListOffset))
        if !oldFormat {
            writer.advance(4) // Skip compressed size
        }
        assert(writer.bytesWritten == rootHeaderLength + nameListOffset)

        // Write map name
        try writer.writeCString(Self.mapName)
        assert(writer.bytesWritten == rootHeaderLength + headerLength)

        // Write resource data
        for resource in resourcesToWrite {
            writer.writeData(resource.data)
        }
        assert(writer.bytesWritten == resourceDataOffset)

        // Write map header
        writer.bigEndian = true
        writer.write(UInt32(mapHeaderLength)) // Offset to type list
        writer.write(UInt32(numTypes))
        assert(writer.bytesWritten == resourceDataOffset + mapHeaderLength)

        // Write types
        for (type, resources) in resourceMap {
            writer.write(UInt32(fourCharString: type.code))
            writer.write(UInt32(resourceListOffset))
            writer.write(UInt32(resources.count))
            resourceListOffset += resources.count * resourceInfoLength
        }

        // Write resources
        for resources in resourceMap.values {
            for resource in resources {
                writer.write(UInt32(index))
                index += 1
                writer.write(UInt32(fourCharString: resource.typeCode))
                writer.write(Int16(resource.id))
                try writer.writeString(resource.name, encoding: .macOSRoman)
                writer.advance(Self.resourceNameLength - resource.name.count)
            }
        }
        assert(writer.bytesWritten == resourceDataOffset + mapLength)
        
        return writer.data
    }
}
