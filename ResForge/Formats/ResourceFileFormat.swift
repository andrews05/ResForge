import Foundation
import RFSupport

protocol ResourceFileFormat {
    associatedtype IDType: FixedWidthInteger
    static var typeName: String { get }
    var filenameExtension: String { get }
    var name: String { get }
    var supportsTypeAttributes: Bool { get }

    static func read(_ data: Data) throws -> [ResourceType: [Resource]]
    static func write(_ resources: [ResourceType: [Resource]]) throws -> Data

    func read(_ data: Data) throws -> [ResourceType: [Resource]]
    func write(_ resources: [ResourceType: [Resource]]) throws -> Data
}

// Implement some typical defaults and helpers for all formats
extension ResourceFileFormat {
    typealias IDType = Int16
    var supportsTypeAttributes: Bool {
        false
    }
    var typeName: String {
        Self.typeName
    }

    static func isValid(id: Int) -> Bool {
        return Int(IDType.min)...Int(IDType.max) ~= id
    }
    func isValid(id: Int) -> Bool {
        return Self.isValid(id: id)
    }

    func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        guard !data.isEmpty else {
            return [:]
        }
        do {
            return try Self.read(data)
        } catch {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func write(_ resources: [ResourceType: [Resource]]) throws -> Data {
        return try Self.write(resources)
    }
}

// Convenience functions for format detection
struct ResourceFormat {
    static func from(data: Data) throws -> any ResourceFileFormat {
        guard !data.isEmpty else {
            // Default to classic
            return ClassicFormat()
        }

        // Rez and Extended start with specific signature
        let reader = BinaryDataReader(data)
        guard let signature = try? reader.readString(length: 4) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if signature == RezFormat.signature {
            return RezFormat()
        } else if signature == ExtendedFormat.signature {
            return ExtendedFormat()
        } else {
            // Fallback to classic
            return ClassicFormat()
        }
    }

    static func from(typeName: String) -> any ResourceFileFormat {
        switch typeName {
        case RezFormat.typeName:
            return RezFormat()
        case ExtendedFormat.typeName:
            return ExtendedFormat()
        default:
            return ClassicFormat()
        }
    }
}

enum ResourceFormatError: LocalizedError {
    case invalidID(Int)
    case typeAttributesNotSupported
    case fileTooBig
    case valueOverflow

    var failureReason: String? {
        switch self {
        case let .invalidID(id):
            return String(format: NSLocalizedString("The ID %ld is out of range for this file format.", comment: ""), id)
        case .typeAttributesNotSupported:
            return NSLocalizedString("Type attributes are not compatible with this file format.", comment: "")
        case .fileTooBig:
            return NSLocalizedString("The maximum file size of this format was exceeded.", comment: "")
        case .valueOverflow:
            return NSLocalizedString("An internal limit of this file format was exceeded.", comment: "")
        }
    }
}
