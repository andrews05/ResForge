import Foundation
import RFSupport

// https://github.com/Olde-Skuul/burgerlib/blob/master/source/file/brrezfile.cpp

struct RezFormat {
    static let signature = "BRGR"
    static let type = 1
    static let mapName = "resource.map"

    static func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        var resources: [ResourceType: [Resource]] = [:]
        let reader = BinaryDataReader(data, bigEndian: false)

        // Read and validate header
        let signature = (try reader.read(bigEndian: true) as UInt32).stringValue
        guard signature == Self.signature else {
            throw ResourceFormatError.invalidData("Incorrect file signature")
        }
        let numGroups = try reader.read() as UInt32
        let headerLength = try reader.read() as UInt32
        let groupType = try reader.read() as UInt32
        let baseIndex = Int(try reader.read() as UInt32)
        let numEntries = Int(try reader.read() as UInt32)
        guard numGroups == 1,
              headerLength <= data.count,
              groupType == Self.type,
              numEntries >= 1
        else {
            throw ResourceFormatError.invalidData("Invalid header")
        }

        // Read resource offsets
        var offsets: [Int] = []
        var sizes: [Int] = []
        for _ in 0..<numEntries {
            offsets.append(Int(try reader.read() as UInt32))
            sizes.append(Int(try reader.read() as UInt32))
            // Skip name offset - we'll just assume the resource map is the last entry
            try reader.advance(4)
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
            let type = (try reader.read() as UInt32).stringValue
            let resourceListOffset = Int(try reader.read() as UInt32) + mapOffset
            let numResources = try reader.read() as UInt32
            let resourceType = ResourceType(type)
            resources[resourceType] = []

            // Read resources
            try reader.pushPosition(resourceListOffset)
            for _ in 0..<numResources {
                let index = Int(try reader.read() as UInt32) - baseIndex
                guard 0..<numEntries ~= index else {
                    throw ResourceFormatError.invalidData("Invalid resource index")
                }
                try reader.advance(4) // Skip type, which we already know
                let id = Int(try reader.read() as Int16)
                let name = try reader.readCString(paddedLength: 256, encoding: .macOSRoman)

                // Read resource data
                try reader.pushPosition(offsets[index])
                let data = try reader.readData(length: sizes[index])
                reader.popPosition()

                // Construct resource
                let resource = Resource(type: resourceType, id: id, name: name, data: data)
                resources[resourceType]?.append(resource)
            }
            reader.popPosition()
        }

        return resources
    }

    static func write(_ resourcesByType: [ResourceType: [Resource]]) throws -> Data {
        // Known constants
        let rootHeaderLength = 12
        let groupHeaderLength = 12
        let resourceOffsetLength = 12
        let mapHeaderLength = 8
        let typeInfoLength = 12
        let resourceNameLength = 256
        let resourceInfoLength = 10 + resourceNameLength

        // Perform some initial calculations
        let numTypes = resourcesByType.count
        let numResources = resourcesByType.values.map(\.count).reduce(0, +)
        let numEntries = numResources + 1 // Resource map is the last entry
        let nameListOffset = groupHeaderLength + (numEntries * resourceOffsetLength)
        let headerLength = nameListOffset + Self.mapName.count + 1
        let numGroups = 1
        var index = 1 // Base index

        let writer = BinaryDataWriter(bigEndian: false)

        // Write root header
        writer.write(UInt32(Self.signature), bigEndian: true)
        writer.write(UInt32(numGroups))
        writer.write(UInt32(headerLength))
        assert(writer.bytesWritten == rootHeaderLength)

        // Write group header
        writer.write(UInt32(Self.type))
        writer.write(UInt32(index))
        writer.write(UInt32(numEntries))
        assert(writer.bytesWritten == rootHeaderLength + groupHeaderLength)

        // Write offsets
        var resourceDataOffset = rootHeaderLength + headerLength
        for (type, resources) in resourcesByType {
            guard type.attributes.isEmpty else {
                throw ResourceFormatError.writeError("Type attributes not supported")
            }
            for resource in resources {
                guard ResourceFileFormat.rez.isValid(id: resource.id) else {
                    throw ResourceFormatError.writeError("Resource id outside of valid range")
                }
                writer.write(UInt32(resourceDataOffset))
                writer.write(UInt32(resource.data.count))
                writer.advance(4) // Skip name offset
                resourceDataOffset += resource.data.count
            }
        }

        // Write map offsets
        var resourceListOffset = mapHeaderLength + (numTypes * typeInfoLength)
        let mapLength = resourceListOffset + (numResources * resourceInfoLength)
        writer.write(UInt32(resourceDataOffset))
        writer.write(UInt32(mapLength))
        writer.write(UInt32(nameListOffset))
        assert(writer.bytesWritten == rootHeaderLength + nameListOffset)

        // Write map name
        try writer.writeString(Self.mapName)
        writer.advance(1) // Null terminator
        assert(writer.bytesWritten == rootHeaderLength + headerLength)

        // Write resource data
        for resources in resourcesByType.values {
            for resource in resources {
                writer.writeData(resource.data)
            }
        }
        assert(writer.bytesWritten == resourceDataOffset)

        // Write map header
        writer.bigEndian = true
        writer.write(UInt32(mapHeaderLength)) // Offset to type list
        writer.write(UInt32(numTypes))
        assert(writer.bytesWritten == resourceDataOffset + mapHeaderLength)

        // Write types
        for (type, resources) in resourcesByType {
            writer.write(UInt32(type.code))
            writer.write(UInt32(resourceListOffset))
            writer.write(UInt32(resources.count))
            resourceListOffset += resources.count * resourceInfoLength
        }

        // Write resources
        for resources in resourcesByType.values {
            for resource in resources {
                writer.write(UInt32(index))
                index += 1
                writer.write(UInt32(resource.typeCode))
                writer.write(Int16(resource.id))
                try writer.writeString(resource.name, encoding: .macOSRoman)
                writer.advance(resourceNameLength - resource.name.count)
            }
        }
        assert(writer.bytesWritten == resourceDataOffset + mapLength)
        
        return writer.data
    }
}
