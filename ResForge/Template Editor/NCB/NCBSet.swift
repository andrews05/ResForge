import Parsing
import RFSupport

/// Parses a full NCB set expression
struct NCBSetExpression: NCBExpression {
    static let parser = Many {
        OneOf {
            NCBSetValue.parser.map { $0 as NCBSet }
            NCBSetRandom.parser.map { $0 as NCBSet }
        }
    } separator: {
        Whitespace(1...)
    } terminator: {
        End()
    }.map(Self.init)

    static func parse(_ input: String) throws -> Self {
        try parser.parse(input)
    }

    static let usage = {
        let ops = NCBSetOp.allCases.map(\.usage).joined(separator: "\n")
        return "\(ops)\n\(NCBSetRandom.usage)\n\n<required value> [optional value]"
    }()

    let ops: [NCBSet]

    func description(manager: RFEditorManager) -> String {
        ops.map {
            $0.description(manager: manager)
        }.joined(separator: "\n")
    }
}

protocol NCBSet {
    func description(manager: RFEditorManager) -> String
}

/// An NCB set operation with associated value
struct NCBSetValue: NCBSet {
    static let parser = OneOf {
        for op in NCBSetOp.allCases {
            Parse(Self.init) {
                op.rawValue.map { op }
                if op.valueRequired {
                    Digits().map { $0 as Int? }
                } else {
                    Optionally { Digits() }
                }
            }
        }
    }

    let op: NCBSetOp
    let value: Int?

    func resource(manager: RFEditorManager) -> Resource? {
        guard let value, let type = op.resourceType else {
            return nil
        }
        return manager.findResource(type: .init(type), id: value, currentDocumentOnly: false)
    }

    func description(manager: RFEditorManager) -> String {
        let text = op.description(value)
        if let resource = self.resource(manager: manager) {
            return "\(text): “\(resource.name)”"
        }
        return text
    }
}

/// A random choice of multiple NCB set operations
struct NCBSetRandom: NCBSet {
    static let description = "Random Choice (50/50)"
    static let usage = "R(<op1> [op2]): \(description)"
    static let parser = Parse(Self.init) {
        "R("
        Many(1...2) {
            NCBSetValue.parser
        } separator: {
            Whitespace(1...)
        } terminator: {
            ")"
        }
    }
    
    let ops: [NCBSetValue]

    func description(manager: RFEditorManager) -> String {
        return ops.reduce("\(Self.description):") {
            $0 + "\n    \($1.description(manager: manager))"
        }
    }
}

/// An NCB set operation
enum NCBSetOp: String, CaseIterable, CustomStringConvertible {
    case set = "B"
    case clear = "!B"
    case toggle = "^B"
    case abortMission = "A"
    case failMission = "F"
    case startMission = "S"
    case grantOutfit = "G"
    case removeOutfit = "D"
    case moveSystem = "M"
    case moveSystemRelative = "N"
    case changeShip = "C"
    case changeShipAll = "E"
    case changeShipDefault = "H"
    case activateRank = "K"
    case deactivateRank = "L"
    case playSound = "P"
    case destroyStellar = "Y"
    case regenerateStellar = "U"
    case leave = "Q"
    case changeShipTitle = "T"
    case exploreSystem = "X"
    
    var valueRequired: Bool {
        self != .leave
    }
    
    var usage: String {
        var valueType = resourceType ?? "bit"
        // Indicate <required> or [optional]
        valueType = valueRequired ? "<\(valueType)>" : "[\(valueType)]"
        return "\(rawValue)\(valueType): \(description)"
    }

    func description(_ value: Int?) -> String {
        guard let value else {
            return description
        }
        var text = description + " "
        // Leave description differs when value provided
        if self == .leave {
            text += "With Message "
        }
        if resourceType != nil {
            text += "#"
        }
        return text + "\(value)"
    }

    var description: String {
        switch self {
        case .set:
            return "Set Bit"
        case .clear:
            return "Clear Bit"
        case .toggle:
            return "Toggle Bit"
        case .abortMission:
            return "Abort Mission"
        case .failMission:
            return "Fail Mission"
        case .startMission:
            return "Start Mission"
        case .grantOutfit:
            return "Grant Outfit"
        case .removeOutfit:
            return "Remove Outfit"
        case .moveSystem:
            return "Move System (first stellar)"
        case .moveSystemRelative:
            return "Move System (keep position)"
        case .changeShip:
            return "Change Ship (keep outfifts)"
        case .changeShipAll:
            return "Change Ship (+default outfits)"
        case .changeShipDefault:
            return "Change Ship (default outfits)"
        case .activateRank:
            return "Activate Rank"
        case .deactivateRank:
            return "Deactive Rank"
        case .playSound:
            return "Play Sound"
        case .destroyStellar:
            return "Destroy Stellar"
        case .regenerateStellar:
            return "Regenerate Stellar"
        case .leave:
            return "Leave Stellar"
        case .changeShipTitle:
            return "Change Ship Title"
        case .exploreSystem:
            return "Explore System"
        }
    }

    var resourceType: String? {
        switch self {
        case .abortMission, .failMission, .startMission:
            return "mïsn"
        case .grantOutfit, .removeOutfit:
            return "oütf"
        case .moveSystem, .moveSystemRelative, .exploreSystem:
            return "sÿst"
        case .changeShip, .changeShipAll, .changeShipDefault:
            return "shïp"
        case .activateRank, .deactivateRank:
            return "ränk"
        case .playSound:
            return "snd "
        case .destroyStellar, .regenerateStellar:
            return "spöb"
        case .leave, .changeShipTitle:
            return "STR#"
        default:
            return nil
        }
    }
}
