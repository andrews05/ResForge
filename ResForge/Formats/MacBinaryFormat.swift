import Foundation
import RFSupport

// https://web.archive.org/web/20050305044255/http://www.lazerware.com/formats/macbinary/macbinary_iii.html

struct MacBinaryFormat: ResourceFileFormat {
    static let typeName = "com.apple.macbinary-archive"
    let name = NSLocalizedString("MacBinary Archive", comment: "")

    static let headerLength = 128
    static let forkLengthOffset = 83
    static let crcOffset = 124

    private var headerAndData = Data()

    // MacBinary II and III are currently supported
    static func matches(data: Data) -> Bool {
        let versionOffset = 122
        let minimumVersionOffset = 123
        let v2version = 129
        let v3version = 130

        guard data.count >= Self.headerLength,
              data[0] == 0,
              data[74] == 0,
              data[82] == 0,
              (data[versionOffset] == v2version || data[versionOffset] == v3version),
              data[minimumVersionOffset] == v2version
        else {
            return false
        }

        return true
    }

    mutating func read(_ data: Data) throws -> [ResourceType: [Resource]] {
        do {
            let reader = BinaryDataReader(data)

            // Validate the CRC
            try reader.setPosition(Self.crcOffset)
            let crc = try reader.read() as UInt16
            guard crc != 0, crc == self.crc16(data[0..<Self.crcOffset]) else {
                throw CocoaError(.fileReadCorruptFile)
            }

            // Read fork lengths
            try reader.setPosition(Self.forkLengthOffset)
            let dataLength = Int(try reader.read() as UInt32)
            let rsrcLength = Int(try reader.read() as UInt32)

            // Calculate resource fork offset
            let rsrcOffset = Self.headerLength + dataLength + self.forkPadding(dataLength)

            // Read resource fork
            try reader.setPosition(rsrcOffset)
            let rsrcFork = try reader.readData(length: rsrcLength)
            let resources = try ClassicFormat.read(rsrcFork)

            // Retain the header and data fork
            headerAndData = data[..<rsrcOffset]

            return resources
        } catch {
            throw CocoaError(.fileReadCorruptFile)
        }
    }

    func write(_ resources: [ResourceType: [Resource]]) throws -> Data {
        // Construct the resource fork
        let rsrcFork = try ClassicFormat.write(resources)

        // Write header and data fork
        let writer = BinaryDataWriter()
        writer.writeData(headerAndData)

        // Update the resource fork length
        writer.write(UInt32(rsrcFork.count), at: Self.forkLengthOffset + 4)

        // Update the CRC
        let crc = self.crc16(writer.data[0..<Self.crcOffset])
        writer.write(crc, at: Self.crcOffset)

        // Write the resource fork and padding
        writer.writeData(rsrcFork)
        writer.advance(self.forkPadding(rsrcFork.count))

        return writer.data
    }

    // Fork data is padded to a multiple of 128
    private func forkPadding(_ size: Int) -> Int {
        let mod = size % 128
        return mod == 0 ? 0 : 128 - mod
    }

    // CRC-CCITT (XModem)
    private func crc16(_ data: Data) -> UInt16 {
        var x: UInt8 = 0
        var crc: UInt16 = 0
        for byte in data {
            x = UInt8(crc >> 8) ^ byte
            x ^= x >> 4
            crc = (crc << 8) ^ (UInt16(x) << 12) ^ (UInt16(x) << 5) ^ UInt16(x)
        }
        return crc
    }
}
