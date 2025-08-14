import Foundation
import RFSupport

class PilotFilter: TemplateFilter {
    static let supportedTypes = ["NpïL"]
    static let name = "Pilot Decrypter"

    static func filter(data: Data, for resourceType: String) -> Data {
        var magic: UInt32 = 0xB36A210F
        var newData = Data(count: data.count)
        data.withUnsafeBytes { input in
            newData.withUnsafeMutableBytes { output in
                // Work through 4 bytes at a time as UInt32
                var i = 0
                while i + 4 <= input.count {
                    var bytes = input.loadUnaligned(fromByteOffset: i, as: UInt32.self)
                    bytes ^= magic.bigEndian
                    magic &+= 0xDEADBEEF
                    magic ^= 0xDEADBEEF
                    output.storeBytes(of: bytes, toByteOffset: i, as: UInt32.self)
                    i += 4
                }
                // Work through remaining bytes
                while i < input.count {
                    output[i] = input[i] ^ UInt8(magic >> 24)
                    magic <<= 8
                    i += 1
                }
            }
        }
        return newData
    }

    static func unfilter(data: Data, for resourceType: String) -> Data {
        // Encryption and decryption are the same
        return Self.filter(data: data, for: resourceType)
    }
}
