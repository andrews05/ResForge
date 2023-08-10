import Foundation
import RFSupport

// https://github.com/Olde-Skuul/burgerlib/blob/master/source/file/brrezfile.cpp

struct RezFormat {
    static let signature = "BRGR"
    static let type = 1
    static let mapName = "resource.map"
    static let resourceOffsetLength = 12
    static let mapHeaderLength = 8
    static let typeInfoLength = 12
    static let resourceInfoLength = 266

    static func read(_ data: Data) throws -> [Resource] {
        var resources: [Resource] = []
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
        let expectedLength = 12 + (numEntries * Self.resourceOffsetLength) + Self.mapName.count + 1
        guard numGroups == 1,
              headerLength == expectedLength,
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
            try reader.advance(4) // Skip name offset
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
                resources.append(resource)
            }
            reader.popPosition()
        }

        return resources
    }
}
