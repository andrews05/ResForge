import Foundation
import RFSupport
import TemplateEditor
import DialogEditor

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
        DialogMeta.register(Self.dialogMetadata)
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

extension ResourceType {
    static let nebula = Self("nëbu")
    static let rle16 = Self("rlëD")
    static let spin = Self("spïn")
    static let spaceObject = Self("spöb")
    static let system = Self("sÿst")
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

extension NovaTools {
    static let dialogMetadata: [Int: DialogMeta] = [
        // Spaceport
        1000: DialogMeta(itemNames: [
            nil,
            nil,
            "Planet name",
            "Recharge",
            "Landing pict",
            "Planet desc",
            "Trade Center",
            "Outfitter",
            "Shipyard",
            "Mission BBS",
            "Bar",
            "Leave",
            "(unused)",
            nil,
            nil,
         ], backgroundPictID: 8500),
        // Trade Center
        1001: DialogMeta(itemNames: [
            "Done",
            nil,
            "Header",
            "Cargo 1",
            "Cargo 2",
            "Cargo 3",
            "Cargo 4",
            "Cargo 5",
            "Cargo 6",
            "Junk 1",
            "Junk 2",
            "Current cargo",
            "Buy",
            "Sell",
            "Active disaster",
            nil,
            nil,
         ], backgroundPictID: 8510),
        // Outfitter
        1002: DialogMeta(itemNames: [
            "Done",
            nil,
            nil,
            "Sell",
            "Outfits grid",
            "Outfit desc",
            "Buy",
            "Outfit pict",
            "Purchase info",
            "Up",
            "Dn",
            nil,
            nil,
         ], backgroundPictID: 8502),
        // Shipyard
        1004: DialogMeta(itemNames: [
            "Buy Ship",
            nil,
            nil,
            nil,
            "Ships grid",
            "Ship desc",
            "Done",
            "Ship pict",
            "Purchase info",
            "Info",
            nil,
            "Up",
            "Dn",
         ], backgroundPictID: 8501),
        // Shipyard Info
        1005: DialogMeta(itemNames: [
            "Done",
            nil,
            "Ship name",
            nil,
            "Ship info",
            nil,
         ], backgroundPictID: 8506),
        // Mission BBS
        1006: DialogMeta(itemNames: [
            "Accept",
            "Mission list",
            "Scroll bar",
            "Offer desc",
            "Mission name",
            nil,
            "Leave",
            "Header",
            nil,
            nil,
            "Current date",
         ], backgroundPictID: 8505),
        // Ship Comm
        1007: DialogMeta(itemNames: [
            "Close Channel",
            "Request Assist",
            "Greetings",
            nil,
            nil,
            nil,
            nil,
            nil,
            "(static text)",
            "Comm text",
            "Ship pict",
            "Ship info",
         ], backgroundPictID: 8511),
        // Negotiation
        1008: DialogMeta(itemNames: [
            "Accept Price",
            "Lower Price",
            "Payment request",
         ], backgroundPictID: 8514),
        // Planet Comm
        1009: DialogMeta(itemNames: [
            "Close Channel",
            "Greetings",
            "Demand Tribute",
            "Comm text",
            "Planet view",
            "Planet info",
         ], backgroundPictID: 8512),
        // Plunder
        1011: DialogMeta(itemNames: [
            "Abort",
            "Cargo",
            "Credits",
            "Ammo",
            "Available plunder",
            "Energy",
            "Capture Ship",
         ], backgroundPictID: 8515),
        // Mission Info
        1012: DialogMeta(itemNames: [
            "Done",
            "Mission list",
            "Header",
            "Quick brief desc",
            "Abort",
            nil,
            "Current date",
         ], backgroundPictID: 8517),
        // Bar
        1013: DialogMeta(itemNames: [
            "Leave",
            "Gamble",
            "Holovid",
            nil,
            "Hire Escort",
            nil,
            "Bar desc",
            nil,
            nil,
            nil,
         ], backgroundPictID: 8503),
        // Mission Offer (multipart background not supported)
        1016: DialogMeta(itemNames: [
            "Yes",
            "No",
            "Desc",
            nil,
            nil,
            "Okay",
            nil,
            nil,
            "Up",
            "Dn",
         ]),
        // Player Info (multipart background not supported)
        1017: DialogMeta(itemNames: [
            "Done",
            "General",
            "Cargo",
            "Extras",
            "Honors",
            "Info content",
            "Jettison Cargo",
         ]),
        // Capture Assignment
        1018: DialogMeta(itemNames: [
            "Use As My Ship",
            "Use As Escort",
            "Prompt text",
         ], backgroundPictID: 8516),
        // Shipyard Info with pict
        1019: DialogMeta(itemNames: [
            "Done",
            nil,
            "Long ship name",
            nil,
            "Ship stats",
            nil,
            "Ship pict",
            "Ship loadout",
         ], backgroundPictID: 8507),
        // Mission Offer with pict
        1020: DialogMeta(itemNames: [
            "Yes",
            "No",
            "Desc",
            nil,
            nil,
            "Okay",
            nil,
            "Pict",
            "Up",
            "Dn",
         ], backgroundPictID: 8528),
        // Bar with pict
        1021: DialogMeta(itemNames: [
            "Leave",
            "Gamble",
            "Holovid",
            nil,
            "Hire Escort",
            nil,
            "Bar desc",
            "Bar pict",
         ], backgroundPictID: 8504),
        // Escort Comm
        1022: DialogMeta(itemNames: [
            "Close Channel",
            "Release",
            "Upgrade Escort",
            "Sell Escort",
            nil,
            nil,
            nil,
            nil,
            "(static text)",
            "Escort info",
            "Ship pict",
            "Ship info",
         ], backgroundPictID: 8513),
        // Race
        1023: DialogMeta(itemNames: [
            "Cancel",
            "Help",
            "Option 1",
            "Option 2",
            "Option 3",
            "Option 4",
         ], backgroundPictID: 8529),
        // Map
        2000: DialogMeta(itemNames: [
            "Done",
            "Ports/hazards",
            "Map view",
            "+",
            "-",
            "System info",
            nil,
            "Clear Route",
            "Show Borders",
            "Find",
         ], backgroundPictID: 8509),
        // Other desc (multipart background not supported)
        3003: DialogMeta(itemNames: [
            "Okay",
            nil,
            "Desc",
            nil,
            "Up",
            "Dn",
         ]),
        // Other desc with pict
        3004: DialogMeta(itemNames: [
            "Okay",
            "Pict",
            "Desc",
            nil,
            "Up",
            "Dn",
         ], backgroundPictID: 8527),
    ]
}
