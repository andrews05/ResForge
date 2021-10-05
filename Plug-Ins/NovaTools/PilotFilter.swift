import Foundation
import RFSupport

class PilotFilter: TemplateFilter {
    static let supportedTypes = ["NpïL"]
    static let name = "Pilot Decrypter"
    
    static func filter(data: Data, for resourceType: String) -> Data {
        var magic: UInt32 = 0xB36A210F
        // Work through 4 bytes at a time by converting to [UInt32] and back
        var newData = data.withUnsafeBytes({ Array($0.bindMemory(to: UInt32.self)) }).map({ i -> UInt32 in
            let j = i ^ magic.bigEndian
            magic &+= 0xDEADBEEF
            magic ^= 0xDEADBEEF
            return j
        }).withUnsafeBufferPointer({ Data(buffer: $0) })
        // Work through remaining bytes
        for i in data[newData.count...] {
            newData.append(i ^ UInt8(magic >> 24))
            magic <<= 8
        }
        return newData
    }
    
    static func unfilter(data: Data, for resourceType: String) -> Data {
        // Encryption and decryption are the same
        return Self.filter(data: data, for: resourceType)
    }
}
