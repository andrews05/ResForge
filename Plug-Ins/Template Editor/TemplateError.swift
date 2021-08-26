import Foundation
import RFSupport

enum TemplateError: LocalizedError, RecoverableError {
    case corrupt
    case unknownElement(String)
    case unclosedElement(Element)
    case unboundedElement(Element)
    case invalidStructure(Element, String)
    case dataMismatch(Element)
    case truncate
    
    var errorDescription: String? {
        switch self {
        case .corrupt:
            return NSLocalizedString("Corrupt or insufficient data.", comment: "")
        case let .unknownElement(type):
            return String(format: NSLocalizedString("Unsupported element type ‘%@’.", comment: ""), type)
        case let .unclosedElement(element):
            return "\(element.type) “\(element.label)”: ".appendingFormat(NSLocalizedString("Closing ‘%@’ element not found.", comment: ""), element.endType)
        case let .unboundedElement(element):
            let message: String
            if let endType = element.endType {
                message = String(format: NSLocalizedString("Closing ‘%@’ must be last element in template or sized section.", comment: ""), endType)
            } else {
                message = NSLocalizedString("Must be last element in template or sized section.", comment: "")
            }
            return "\(element.type) “\(element.label)”: ".appending(message)
        case let .invalidStructure(element, message):
            return "\(element.type) “\(element.label)”: ".appending(message)
        case .dataMismatch:
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
    
    var recoveryOptions: [String] {
        switch self {
        case .dataMismatch:
            return [NSLocalizedString("OK", comment: ""), NSLocalizedString("Open with Hex Editor", comment: "")]
        default:
            return []
        }
    }
    
    func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool {
        if recoveryOptionIndex == 1, case let .dataMismatch(element) = self {
            let controller = element.parentList.controller!
            controller.manager.open(resource: controller.resource, using: PluginRegistry.hexEditor, template: "")
        }
        return false
    }
}
