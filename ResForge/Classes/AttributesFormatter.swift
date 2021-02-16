import Foundation
import RFSupport

class AttributesFormatter: Formatter {
    static let names: [ResAttributes: (full: String, short: String)] = [
        .preload: ("Preload", "Pre"),
        .protected: ("Protected", "Pro"),
        .locked: ("Locked", "L"),
        .purgeable: ("Purgeable", "Pur"),
        .sysHeap: ("SysHeap", "Sys")
    ]
    
    override func string(for obj: Any?) -> String? {
        guard let attributes = obj as? ResAttributes else {
            return nil
        }
        let list = [.preload, .protected, .locked, .purgeable, .sysHeap].filter { attributes.contains($0) }
        return list.map {
            let name = Self.names[$0]!
            return list.count > 2 ? name.short : name.full
        }.joined(separator: ", ")
    }
}
