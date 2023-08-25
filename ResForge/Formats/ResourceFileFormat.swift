import Foundation
import RFSupport

protocol ResourceFileFormat {
    associatedtype IDType: FixedWidthInteger
    static var typeName: String { get }
    var name: String { get }
    var supportsResAttributes: Bool { get }
    var supportsTypeAttributes: Bool { get }

    func filenameExtension(for url: URL?) -> String?
    func read(_ data: Data) throws -> [ResourceType: [Resource]]
    func write(_ resources: [ResourceType: [Resource]]) throws -> Data
}

// Implement some typical defaults and helpers for all formats
extension ResourceFileFormat {
    typealias IDType = Int16
    var typeName: String {
        Self.typeName
    }
    var supportsResAttributes: Bool {
        false
    }
    var supportsTypeAttributes: Bool {
        false
    }

    func filenameExtension(for url: URL?) -> String? {
        return nil
    }

    static func isValid(id: Int) -> Bool {
        return Int(IDType.min)...Int(IDType.max) ~= id
    }
    func isValid(id: Int) -> Bool {
        return Self.isValid(id: id)
    }
}

// Convenience functions for format detection
struct ResourceFormat {
    // We can only create new files of these types
    static let creatableTypes = [
        ClassicFormat.typeName,
        RezFormat.typeName,
        ExtendedFormat.typeName,
    ]

    static func from(data: Data) throws -> any ResourceFileFormat {
        guard !data.isEmpty else {
            // Default to classic
            return ClassicFormat()
        }

        // Start by checking 4 byte signature
        let reader = BinaryDataReader(data)
        guard let signature = try? reader.read() as UInt32 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        switch signature {
        case RezFormat.signature:
            return RezFormat()
        case ExtendedFormat.signature:
            return ExtendedFormat()
        case AppleSingleFormat.signature:
            return AppleSingleFormat()
        case AppleDoubleFormat.signature:
            return AppleDoubleFormat()
        case _ where MacBinaryFormat.matches(data: data):
            return MacBinaryFormat()
        default:
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
