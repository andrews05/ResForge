import Parsing
import RFSupport

/// Parses a full NCB test expression
struct NCBTestExpression: NCBExpression {
    static let parser = OneOf {
        NCBTestCombiner.AND.parser(1...2, terminator: End())
        NCBTestCombiner.OR.parser(1...2, terminator: End())
    }

    static func parse(_ input: String) throws -> Self {
        try parser.parse(input)
    }

    static let usage = {
        let ops = NCBTestOp.allCases.map(\.usage).joined(separator: "\n")
        let combiners = NCBTestCombiner.allCases.map(\.usage).joined(separator: "\n")
        return "\(ops)\n\(combiners)\n!<op>: Negate operation"
    }()

    let ops: [NCBTest]
    let combiner: NCBTestCombiner

    func description(manager: RFSupport.RFEditorManager) -> String {
        return self.description(manager: manager, indent: "", negate: false)
    }

    func description(manager: RFSupport.RFEditorManager, indent: String, negate: Bool) -> String {
        if ops.count == 1 {
            return ops[0].description(manager: manager, indent: indent)
        }
        let prefix: String
        if combiner == .AND {
            prefix = negate ? "Not Both" : "Both"
        } else {
            prefix = negate ? "Neither" : "Either"
        }
        let text = ops.map {
            $0.description(manager: manager, indent: "\(indent)    ")
        }.joined(separator: "\n")
        return "\(indent)\(prefix) (\n\(text)\n\(indent))"
    }
}

protocol NCBTest {
    func description(manager: RFEditorManager, indent: String) -> String
}

/// A parenthetically enclosed NCB test expression
struct NCBTestWrapped: NCBTest {
    static let parser: AnyParser<Substring, Self> = Lazy {
        Optionally {
            "!"
        }.map { $0 != nil }
        "("
        OneOf {
            NCBTestCombiner.AND.parser(2, terminator: ")")
            NCBTestCombiner.OR.parser(2, terminator: ")")
        }
    }.map(Self.init).eraseToAnyParser()
    
    let negate: Bool
    let expression: NCBTestExpression
    
    func description(manager: RFSupport.RFEditorManager, indent: String) -> String {
        return expression.description(manager: manager, indent: indent, negate: negate)
    }
}

/// An NCB test operation with associated value
struct NCBTestValue: NCBTest {
    static let parser = OneOf {
        for op in NCBTestOp.allCases {
            Parse(Self.init) {
                Optionally {
                    "!"
                }.map { $0 != nil }
                op.rawValue.map { op }
                if op.hasValue {
                    Digits().map { $0 as Int? }
                } else {
                    Always(nil as Int?)
                }
            }
        }
    }
    
    let negate: Bool
    let op: NCBTestOp
    let value: Int?

    func resource(manager: RFEditorManager) -> Resource? {
        guard let value, let type = op.resourceType else {
            return nil
        }
        return manager.findResource(type: .init(type), id: value, currentDocumentOnly: false)
    }

    func description(manager: RFEditorManager, indent: String) -> String {
        let text = indent + op.description(value, negate: negate)
        if let resource = self.resource(manager: manager) {
            return "\(text): “\(resource.name)”"
        }
        return text
    }
}

/// An NCB test logical combiner
enum NCBTestCombiner: String, CaseIterable {
    case AND = "&"
    case OR = "|"
    
    var usage: String {
        let text = "<op1> \(rawValue) <op2>: "
        switch self {
        case .AND:
            return text + "Both operations"
        case .OR:
            return text + "Either operation"
        }
    }
    
    func parser<Terminator: Parser>(_ length: CountingRange, terminator: Terminator) -> AnyParser<Substring, NCBTestExpression> where Terminator.Input == Substring {
        Many(length) {
            OneOf {
                NCBTestValue.parser.map { $0 as NCBTest }
                NCBTestWrapped.parser.map { $0 as NCBTest }
            }
        } separator: {
            Whitespace(1...)
            rawValue
            Whitespace(1...)
        } terminator: {
            terminator
        }.map {
            NCBTestExpression(ops: $0, combiner: self)
        }.eraseToAnyParser()
    }
}

/// An NCB test operation
enum NCBTestOp: String, CaseIterable {
    case bitSet = "B"
    case registered = "P"
    case gender = "G"
    case hasOutfit = "O"
    case exploredSystem = "E"
    
    var hasValue: Bool {
        self != .gender
    }
    
    var usage: String {
        var text = rawValue
        if let valueType {
            text += "<\(valueType)>"
        }
        text += ": "
        switch self {
        case .bitSet:
            text += "Bit Set"
        case .registered:
            text += "Unregistered Days"
        case .gender:
            text += "Player Gender (true = Male, false = Female)"
        case .hasOutfit:
            text += "Have Outfit"
        case .exploredSystem:
            text += "Explored System"
        }
        return text
    }

    func description(_ value: Int?, negate: Bool) -> String {
        let value = value ?? 0
        switch self {
        case .bitSet:
            return "Bit \(value) " + (negate ? "Clear" : "Set")
        case .registered:
            return "Unregistered " + (negate ? "More Than" : "At Most") + " \(value) Days"
        case .gender:
            return (negate ? "Female" : "Male") + " Player"
        case .hasOutfit:
            return (negate ? "Have No" : "Have") + " Outfit #\(value)"
        case .exploredSystem:
            return (negate ? "Unexplored" : "Explored") + " System #\(value)"
        }
    }
    
    var valueType: String? {
        switch self {
        case .bitSet:
            return "bit"
        case .registered:
            return "days"
        case .gender:
            return nil
        case .hasOutfit, .exploredSystem:
            return resourceType
        }
    }

    var resourceType: String? {
        switch self {
        case .hasOutfit:
            return "oütf"
        case .exploredSystem:
            return "sÿst"
        default:
            return nil
        }
    }
}
