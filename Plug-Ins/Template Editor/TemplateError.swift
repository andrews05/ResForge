import Foundation

enum TemplateError: LocalizedError {
    case corrupt
    case unknownElement(String)
    case unclosedElement(Element)
    case invalidStructure(Element, String)
    case dataMismtach
    case truncate
    var errorDescription: String? {
        switch self {
        case .corrupt:
            return NSLocalizedString("Corrupt or insufficient data.", comment: "")
        case let .unknownElement(type):
            return String(format: NSLocalizedString("Unknown element type ‘%@’.", comment: ""), type)
        case let .unclosedElement(element):
            return "\(element.type) “\(element.label)”: ".appendingFormat(NSLocalizedString("Closing ‘%@’ element not found.", comment: ""), element.type, element.endType)
        case let .invalidStructure(element, message):
            return "\(element.type) “\(element.label)”: ".appending(message)
        case .dataMismtach:
            return NSLocalizedString("The resource’s data cannot be interpreted by the template.", comment: "")
        case .truncate:
            return NSLocalizedString("The resource contains more data than will fit the template.", comment: "")
        }
    }
    var recoverySuggestion: String? {
        switch self {
        case .truncate:
            return NSLocalizedString("Saving the resource will truncate the data.", comment: "")
        default:
            return nil
        }
    }
}
