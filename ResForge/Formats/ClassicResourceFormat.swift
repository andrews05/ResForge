import RFSupport

// https://developer.apple.com/library/archive/documentation/mac/pdf/MoreMacintoshToolbox.pdf#page=151


enum ResourceFormatError: LocalizedError {
    case invalidData(String)
}

struct ClassicResourceFormat {
    public static func read(_ data: Data) throws -> [Resource] {
        var resources: [Resource] = []
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

            // Read resources
            let pos = reader.position
            try reader.setPosition(resourceListOffset)
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
                resources.append(resource)
            }
            try reader.setPosition(pos)
        }

        return resources
    }
}
