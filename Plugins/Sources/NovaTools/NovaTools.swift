import Foundation
import RFSupport
import TemplateEditor

public class NovaTools: RFPlugin {
    public static var bundle: Bundle { .module }
    public static func register() {
        PluginRegistry.register(self)
        PluginRegistry.register(GalaxyWindowController.self)
        PluginRegistry.register(ShanWindowController.self)
        PluginRegistry.register(SpriteWindowController.self)
        PluginRegistry.register(SystemWindowController.self)
        PluginRegistry.register(PilotFilter.self)
        PluginRegistry.register(SpobFilter.self)
        TemplateParser.register("n", ElementNCB.self)
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
