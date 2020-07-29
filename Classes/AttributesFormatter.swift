import Foundation
import RKSupport

class AttributesFormatter: Formatter {
    static let names: [Int: (full: String, short: String)] = [
        ResAttributes.preload.rawValue: ("Preload", "Pre"),
        ResAttributes.protected.rawValue: ("Protected", "Pro"),
        ResAttributes.locked.rawValue: ("Locked", "L"),
        ResAttributes.purgeable.rawValue: ("Purgeable", "Pur"),
        ResAttributes.sysHeap.rawValue: ("SysHeap", "Sys")
    ]
    
    override func string(for obj: Any?) -> String? {
        guard let attributes = obj as? ResAttributes else {
            return nil
        }
        let list = [.preload, .protected, .locked, .purgeable, .sysHeap].filter { attributes.contains($0) }
        return list.map {
            let name = Self.names[$0.rawValue]!
            return list.count > 2 ? name.short : name.full
        }.joined(separator: ", ")
    }
}
