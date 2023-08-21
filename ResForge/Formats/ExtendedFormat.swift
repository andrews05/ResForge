import Foundation
import RFSupport

// https://github.com/TheDiamondProject/Graphite

struct ExtendedFormat: ResourceFileFormat {
    typealias IDType = Int32 // Technically supports 64-bit but we limit to 32-bit
    static let typeName = "com.resforge.extended-resource-file"
    let name = NSLocalizedString("Extended Resource File", comment: "")
    let supportsTypeAttributes = true

    static let signature = "RSRX"
    static let version = 1

    func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        var resourcesByType: [ResourceType: [Resource]] = [:]
        let reader = BinaryDataReader(data)

        // Read and validate header
        let signature = try reader.readString(length: 4)
        let version = try reader.read() as UInt32
        let dataOffset = try reader.readUInt64AsInt()
        let mapOffset = try reader.readUInt64AsInt()
        let dataLength = try reader.readUInt64AsInt()
        let mapLength = try reader.readUInt64AsInt()
        guard signature == Self.signature,
              version == Self.version,
              dataOffset != 0,
              mapOffset != 0,
              mapLength != 0,
              mapOffset == dataOffset + dataLength,
              mapOffset + mapLength <= data.count
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Go to map
        try reader.setPosition(Int(mapOffset))

        // Read and validate second header
        let dataOffset2 = try reader.readUInt64AsInt()
        let mapOffset2 = try reader.readUInt64AsInt()
        let dataLength2 = try reader.readUInt64AsInt()
        let mapLength2 = try reader.readUInt64AsInt()
        guard dataOffset2 == dataOffset,
              mapOffset2 == mapOffset,
              dataLength2 == dataLength,
              mapLength2 == mapLength
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Read map info
        try reader.advance(8) // Skip handle to next map, file ref, and file attributes
        let typeListOffset = try reader.readUInt64AsInt() + mapOffset
        let nameListOffset = try reader.readUInt64AsInt() + mapOffset
        let attrListOffset = try reader.readUInt64AsInt()

        // Read types
        try reader.setPosition(typeListOffset)
        // Use overflow addition to get counts
        let numTypes = (try reader.read() as UInt64) &+ 1
        for _ in 0..<numTypes {
            let type = (try reader.read() as UInt32).stringValue
            let numResources = (try reader.read() as UInt64) &+ 1
            let resourceListOffset = try reader.readUInt64AsInt() + typeListOffset
            let numAttributes = try reader.readUInt64AsInt()
            let attributesOffset = try reader.readUInt64AsInt() + attrListOffset

            // Read attributes
            var attributes: [String: String] = [:]
            if numAttributes > 0 {
                try reader.pushPosition(attributesOffset)
                for _ in 0..<numAttributes {
                    let key = try reader.readCString(encoding: .macOSRoman)
                    attributes[key] = try reader.readCString(encoding: .macOSRoman)
                }
                reader.popPosition()
            }

            let resourceType = ResourceType(type, attributes)

            // Read resources
            try reader.pushPosition(resourceListOffset)
            var resources: [Resource] = []
            for _ in 0..<numResources {
                let id = Int(try reader.read() as Int64)
                let nameOffset = try reader.read() as UInt64
                let attributes = Int(try reader.read() as UInt8)
                let resourceDataOffset = try reader.readUInt64AsInt() + dataOffset
                let pos = reader.position + 4 // Skip handle to resource

                // Read resource name
                let name: String
                if nameOffset != UInt64.max {
                    guard nameOffset <= UInt32.max else {
                        throw CocoaError(.validationNumberTooLarge)
                    }
                    try reader.setPosition(Int(nameOffset) + nameListOffset)
                    name = try reader.readPString()
                } else {
                    name = ""
                }

                // Read resource data
                try reader.setPosition(resourceDataOffset)
                let resourceLength = try reader.readUInt64AsInt()
                let data = try reader.readData(length: resourceLength)
                try reader.setPosition(pos)

                // Construct resource
                let resource = Resource(type: resourceType, id: id, name: name, data: data)
                resource.attributes = attributes
                resources.append(resource)
            }
            resourcesByType[resourceType] = resources
            reader.popPosition()
        }

        return resourcesByType
    }

    func write(_ resourcesByType: [ResourceType: [Resource]]) throws -> Data {
        // Known constants
        let dataOffset = 256
        let mapHeaderLength = 40
        let typeInfoLength = 36
        let resourceInfoLength = 29

        // Perform some initial calculations and validations
        let numTypes = resourcesByType.count
        let numResources = resourcesByType.values.map(\.count).reduce(0, +)
        let typeListOffset = mapHeaderLength + 24
        let nameListOffset = typeListOffset + 8 + (numTypes * typeInfoLength) + (numResources * resourceInfoLength)

        let writer = BinaryDataWriter()
        try writer.writeString(Self.signature)
        writer.write(UInt32(Self.version))
        writer.advance(dataOffset - writer.bytesWritten) // Skip offsets for now

        // Write resource data
        var resourceOffsets: [Int] = []
        for resources in resourcesByType.values {
            for resource in resources {
                let offset = writer.bytesWritten - dataOffset
                resourceOffsets.append(offset)
                writer.write(UInt64(resource.data.count))
                writer.writeData(resource.data)
            }
        }

        let mapOffset = writer.bytesWritten
        writer.advance(mapHeaderLength) // Skip map header for now
        writer.write(UInt64(typeListOffset))
        writer.write(UInt64(nameListOffset))
        let attrListOffsetPosition = writer.bytesWritten
        writer.advance(8) // Skip attribute list offset for now

        // Write types
        writer.write(UInt64(numTypes) &- 1)
        let attributeList = BinaryDataWriter()
        var resourceListOffset = 8 + (numTypes * typeInfoLength)
        for (type, resources) in resourcesByType {
            writer.write(UInt32(type.code))
            writer.write(UInt64(resources.count) &- 1)
            writer.write(UInt64(resourceListOffset))
            writer.write(UInt64(type.attributes.count))
            writer.write(UInt64(attributeList.bytesWritten))
            for (key, value) in type.attributes {
                try attributeList.writeCString(key, encoding: .macOSRoman)
                try attributeList.writeCString(value, encoding: .macOSRoman)
            }
            resourceListOffset += resources.count * resourceInfoLength
        }

        // Write resources
        let nameList = BinaryDataWriter()
        // For improved performance, reverse the offsets so we can pop them quickly off the end in the loop
        resourceOffsets.reverse()
        for resources in resourcesByType.values {
            for resource in resources {
                writer.write(Int64(resource.id))
                if resource.name.isEmpty {
                    writer.write(UInt64.max)
                } else {
                    writer.write(UInt64(nameList.bytesWritten))
                    try nameList.writePString(resource.name)
                }

                writer.write(UInt8(resource.attributes))
                let resourceDataOffset = resourceOffsets.removeLast()
                writer.write(UInt64(resourceDataOffset))
                writer.advance(4) // Skip handle to next resource
            }
        }

        // Write resource names
        writer.writeData(nameList.data)

        // Write type attributes
        let attrListOffset = writer.bytesWritten
        writer.write(UInt64(attrListOffset), at: attrListOffsetPosition)
        writer.writeData(attributeList.data)

        // Go back and write headers
        let dataLength = mapOffset - dataOffset
        let mapLength = writer.bytesWritten - mapOffset
        writer.write(UInt64(dataOffset), at: 8)
        writer.write(UInt64(mapOffset), at: 16)
        writer.write(UInt64(dataLength), at: 24)
        writer.write(UInt64(mapLength), at: 32)
        writer.writeData(writer.data[8..<40], at: mapOffset)

        return writer.data
    }
}

fileprivate extension BinaryDataReader {
    /// Read a UInt64 value and return as Int, throwing an error if the value is too large.
    func readUInt64AsInt() throws -> Int {
        let val = try self.read() as UInt64
        // For extra safety we restrict to UInt32.max
        // This ensures we can still do calculations without exceeding Int.max
        guard val <= UInt32.max else {
            throw CocoaError(.validationNumberTooLarge)
        }
        return Int(val)
    }
}
