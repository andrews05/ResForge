import Foundation
import RFSupport

enum ResourceFormatError: LocalizedError {
    case invalidData(String)
    case writeError(String)
}

extension ResourceFileFormat {
    static func read(from url: URL) throws -> (Self, [ResourceType: [Resource]]) {
        let content = try Data(contentsOf: url)
        let format = try self.detectFormat(content)
        return (format, try format.read(content))
    }

    static func detectFormat(_ data: Data) throws -> Self {
        let reader = BinaryDataReader(data)

        // Rez starts with specific signature
        let first = try reader.read() as UInt32
        if first.stringValue == RezFormat.signature {
            return .rez
        }

        // Extended starts with 8 byte version number, currently 1
        let second = try reader.read() as UInt32
        if first == 0 && second == 1 {
            return .extended
        }

        // Otherwise fallback to classic
        return .classic
    }

    func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        switch self {
        case .classic:
            return try ClassicFormat.read(data)
        case .rez:
            return try RezFormat.read(data)
        case .extended:
            // The Objective-C bridge to Graphite can't work with `ResourceType`
            // We need to construct the dictionary here instead
            let resources = try ResourceFile.readExtended(data)
            var byType: [ResourceType: [Resource]] = [:]
            for resource in resources {
                if byType[resource.type] == nil {
                    byType[resource.type] = [resource]
                } else {
                    byType[resource.type]?.append(resource)
                }
            }
            return byType
        }
    }

    func write(_ resourcesByType: [ResourceType: [Resource]], to url: URL) throws {
        switch self {
        case .classic:
            let data = try ClassicFormat.write(resourcesByType)
            try data.write(to: url)
        default:
            let resources = Array(resourcesByType.values.joined())
            try ResourceFile.write(resources, to: url, as: self)
        }
    }
}
