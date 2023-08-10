import Foundation
import RFSupport

enum ResourceFormatError: LocalizedError {
    case invalidData(String)
}

extension ResourceFileFormat {
    static func read(from url: URL) throws -> (Self, [Resource]) {
        let content = try Data(contentsOf: url)
        let format = try self.detectFormat(content)
        return (format, try format.read(content))
    }

    static func detectFormat(_ data: Data) throws -> ResourceFileFormat {
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

    func read(_ data: Data) throws -> [Resource] {
        switch self {
        case .classic:
            return try ClassicResourceFormat.read(data)
        case .rez:
            return try RezFormat.read(data)
        case .extended:
            return try ResourceFile.readExtended(data)
        }
    }
}
