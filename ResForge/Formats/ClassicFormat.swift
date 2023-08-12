import Foundation
import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/MoreMacintoshToolbox.pdf#page=151

struct ClassicFormat {
    static func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        var resources: [ResourceType: [Resource]] = [:]
        let reader = BinaryDataReader(data)

        // Read and validate header
        let dataOffset = Int(try reader.read() as UInt32)
        let mapOffset = Int(try reader.read() as UInt32)
        let dataLength = Int(try reader.read() as UInt32)
        let mapLength = Int(try reader.read() as UInt32)
        guard dataOffset != 0,
              mapOffset != 0,
              mapLength != 0,
              mapOffset == dataOffset + dataLength
        else {
            throw ResourceFormatError.invalidData("Invalid header")
        }
        guard mapOffset + mapLength <= data.count else {
            throw ResourceFormatError.invalidData("Invalid data length")
        }

        // Go to map
        try reader.setPosition(Int(mapOffset))

        // Read and validate second header
        let dataOffset2 = try reader.read() as UInt32
        let mapOffset2 = try reader.read() as UInt32
        let dataLength2 = try reader.read() as UInt32
        let mapLength2 = try reader.read() as UInt32
        // Skip validation if all zero
        if dataOffset2 != 0 || mapOffset2 != 0 || dataLength2 != 0 || mapLength2 != 0 {
            guard dataOffset2 == dataOffset,
                  mapOffset2 == mapOffset,
                  dataLength2 == dataLength,
                  mapLength2 == mapLength
            else {
                throw ResourceFormatError.invalidData("Invalid second header")
            }
        }

        // Read map info
        try reader.advance(8) // Skip handle to next map, file ref, and file attributes
        let typeListOffset = Int(try reader.read() as UInt16) + mapOffset
        let nameListOffset = Int(try reader.read() as UInt16) + mapOffset

        // Read types
        try reader.setPosition(typeListOffset)
        // Use overflow addition to get counts
        let numTypes = (try reader.read() as UInt16) &+ 1
        for _ in 0..<numTypes {
            let type = (try reader.read() as UInt32).stringValue
            let numResources = (try reader.read() as UInt16) &+ 1
            let resourceListOffset = Int(try reader.read() as UInt16) + typeListOffset
            let resourceType = ResourceType(type)
            resources[resourceType] = []

            // Read resources
            try reader.pushPosition(resourceListOffset)
            for _ in 0..<numResources {
                let id = Int(try reader.read() as Int16)
                let nameOffset = try reader.read() as UInt16
                // 1 byte for attributes followed by 3 bytes for offset
                let attsAndOffset = try reader.read() as UInt32
                let attributes = Int(attsAndOffset >> 24)
                let resourceDataOffset = Int(attsAndOffset & 0x00FFFFFF) + dataOffset
                let pos = reader.position + 4 // Skip handle to resource

                // Read resource name
                let name: String
                if nameOffset != UInt16.max {
                    try reader.setPosition(Int(nameOffset) + nameListOffset)
                    name = try reader.readPString()
                } else {
                    name = ""
                }

                // Read resource data
                try reader.setPosition(resourceDataOffset)
                let resourceLength = Int(try reader.read() as UInt32)
                let data = try reader.readData(length: resourceLength)
                try reader.setPosition(pos)

                // Construct resource
                let resource = Resource(type: resourceType, id: id, name: name, data: data)
                resource.attributes = attributes
                resources[resourceType]?.append(resource)
            }
            reader.popPosition()
        }

        return resources
    }

    static func write(_ resourcesByType: [ResourceType: [Resource]]) throws -> Data {
        // Known constants
        let dataOffset = 256
        let dataSizeMask = (1 << 24) - 1
        let mapHeaderLength = 24
        let typeInfoLength = 8
        let resourceInfoLength = 12

        // Perform some initial calculations and validations
        let numTypes = resourcesByType.count
        let numResources = resourcesByType.values.map(\.count).reduce(0, +)
        let typeListOffset = mapHeaderLength + 4
        let nameListOffset = typeListOffset + 2 + (numTypes * typeInfoLength) + (numResources * resourceInfoLength)
        // Trivia: Total number of resources can never exceed 5458
        guard nameListOffset <= UInt16.max else {
            throw ResourceFormatError.writeError("Name list offset would exceed maximum value")
        }

        let writer = BinaryDataWriter()
        writer.advance(dataOffset) // Skip header for now

        // Write resource data
        var resourceOffsets: [Int] = []
        for (type, resources) in resourcesByType {
            guard type.attributes.isEmpty else {
                throw ResourceFormatError.writeError("Type attributes not supported")
            }
            for resource in resources {
                guard ResourceFileFormat.classic.isValid(id: resource.id) else {
                    throw ResourceFormatError.writeError("Resource id outside of valid range")
                }
                let offset = writer.bytesWritten - dataOffset
                guard offset <= dataSizeMask else {
                    throw ResourceFormatError.writeError("Resource data offset would exceed maximum value")
                }
                resourceOffsets.append(offset)
                writer.write(UInt32(resource.data.count))
                writer.writeData(resource.data)
            }
        }

        let mapOffset = writer.bytesWritten
        writer.advance(mapHeaderLength) // Skip map header for now
        writer.write(UInt16(typeListOffset))
        writer.write(UInt16(nameListOffset))

        // Write types
        writer.write(UInt16(numTypes) &- 1)
        var resourceListOffset = 2 + (numTypes * typeInfoLength)
        for (type, resources) in resourcesByType {
            writer.write(UInt32(type.code))
            writer.write(UInt16(resources.count) &- 1)
            writer.write(UInt16(resourceListOffset))
            resourceListOffset += resources.count * resourceInfoLength
        }

        // Write resources
        let nameList = BinaryDataWriter()
        // For improved performance, reverse the offsets so we can pop them quickly off the end in the loop
        resourceOffsets.reverse()
        for resources in resourcesByType.values {
            for resource in resources {
                writer.write(Int16(resource.id))
                if resource.name.isEmpty {
                    writer.write(UInt16.max)
                } else if nameList.bytesWritten >= UInt16.max {
                    throw ResourceFormatError.writeError("Resource name offset would exceed maximum value")
                } else {
                    writer.write(UInt16(nameList.bytesWritten))
                    try nameList.writePString(resource.name)
                }

                let resourceDataOffset = resourceOffsets.removeLast()
                let attsAndOffset = UInt32(resource.attributes) << 24 | UInt32(resourceDataOffset)
                writer.write(attsAndOffset)
                writer.advance(4) // Skip handle to next resource
            }
        }

        // Write resource names
        writer.writeData(nameList.data)

        // Even if the data is valid so far, the resource manager will still not read files larger than 16MB
        // (Specifically, the max seems to be (2 ^ 24) - 2)
        guard writer.bytesWritten < dataSizeMask else {
            throw ResourceFormatError.writeError("File would exceed maximum size")
        }

        // Go back and write headers
        let dataLength = mapOffset - dataOffset
        let mapLength = writer.bytesWritten - mapOffset
        writer.write(UInt32(dataOffset), at: 0)
        writer.write(UInt32(mapOffset), at: 4)
        writer.write(UInt32(dataLength), at: 8)
        writer.write(UInt32(mapLength), at: 12)
        writer.writeData(writer.data[0..<16], at: mapOffset)

        return writer.data
    }
}
