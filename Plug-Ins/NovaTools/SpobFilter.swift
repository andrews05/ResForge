import Foundation
import RFSupport

/*
 * This filter rewrites the spob DefCount field to use the first 12
 * bits for the total count and the remaining 4 bits for the wave size.
 * The allows a template to interpret it using WB12 and WB04.
 *
 * From the EV Nova Bible, spöb DefCount: If you set this number
 * to be above 1000, ships will be launched from the planet or
 * station in waves. The last number in this field is the number of
 * ships in each wave, and the first 3-4 numbers (minus 1 from the
 * first digit) are the total number of ships in the planet's
 * fleet. For example, a value of 1082 would be four waves of two
 * ships for a total of eight. A value of 2005 would create waves
 * of five ships each, with 100 ships total in the planet's defense
 * fleet.
 */

class SpobFilter: TemplateFilter {
    static let supportedTypes = ["spöb"]
    static let name = "Defense Fleet Demangler"
    
    static func filter(data: Data, for resourceType: String) -> Data {
        guard data.endIndex >= 32, (data[30] != 0 || data[31] != 0) else {
            return data
        }
        var defCount = Int16(bitPattern: UInt16(data[30]) << 8 | UInt16(data[31]))
        var waveSize: Int16 = 0
        if defCount < 0 {
            defCount = 0
        } else if defCount >= 1000 {
            defCount -= defCount >= 10000 ? 10000 : 1000
            waveSize = defCount % 10
            defCount /= 10
        }
        var data = data
        data[30] = UInt8(defCount >> 4)
        data[31] = UInt8((defCount & 0x0F) << 4 + waveSize)
        return data
    }
    
    static func unfilter(data: Data, for resourceType: String) -> Data {
        guard data.endIndex >= 32, (data[30] != 0 || data[31] != 0) else {
            return data
        }
        var defCount = Int16(data[30]) << 4 | Int16(data[31]) >> 4
        var waveSize = data[31] & 0x0F
        if waveSize > 0 || defCount >= 1000 {
            // Int16.max = 32767, which equals a total of 2276 in waves of 7
            // For waves of size 8 or 9, the max total is 2275
            waveSize = min(waveSize, 9)
            defCount = min(defCount, waveSize > 7 ? 2275 : 2276)
            defCount *= 10
            defCount += 10000 + Int16(waveSize)
        }
        var data = data
        data[30] = UInt8(defCount >> 8)
        data[31] = UInt8(defCount & 0xFF)
        return data
    }
}
