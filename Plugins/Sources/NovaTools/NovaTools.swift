import Foundation
import RFSupport

public class NovaTools: RFPlugin {
    public static var bundle: Bundle { .module }
    public static func register() {
        PluginRegistry.registerClass(self)
        PluginRegistry.registerClass(GalaxyWindowController.self)
        PluginRegistry.registerClass(ShanWindowController.self)
        PluginRegistry.registerClass(SpriteWindowController.self)
        PluginRegistry.registerClass(SystemWindowController.self)
        PluginRegistry.registerClass(PilotFilter.self)
        PluginRegistry.registerClass(SpobFilter.self)
    }
}

extension NovaTools: PlaceholderProvider {
    public static var supportedTypes = ["dësc"]

    public static func placeholderName(for resource: Resource) -> String? {
        switch resource.typeCode {
        case "dësc":
            guard let end = resource.data.firstIndex(of: 0) else {
                return nil
            }
            let data = resource.data.prefix(upTo: end).prefix(100)
            return String(data: data, encoding: .macOSRoman)
        default:
            return nil
        }
    }
}

extension NovaTools: TypeIconProvider {
    public static var typeIcons = [
        "bööm": "💥",
        "chär": "🧑‍🚀",
        "cölr": "🎨",
        "crön": "⏱️",
        "dësc": "💬",
        "düde": "👱‍♂️",
        "flët": "🚢",
        "gövt": "🏴‍☠️",
        "ïntf": "🔘",
        "jünk": "💎",
        "mïsn": "📦",
        "nëbu": "🦠",
        "öops": "💩",
        "oütf": "🔧",
        "përs": "👤",
        "ränk": "🎖️",
        "rlëD": "🎬",
        "röid": "☄️",
        "shän": "🪄",
        "shïp": "🚀",
        "spïn": "🌀",
        "spöb": "🪐",
        "sÿst": "💫",
        "wëap": "🔫",
        "l33t": "🤡",
    ]
}

extension ResourceType {
    static let nebula = Self("nëbu")
    static let rle16 = Self("rlëD")
    static let spin = Self("spïn")
    static let spaceObject = Self("spöb")
    static let system = Self("sÿst")
}
