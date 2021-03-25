import Foundation
import RFSupport

// Extend the Resource class to validate type and id by checking for conflicts
extension Resource {
    @objc func validateType(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(type: ioValue.pointee as! String, id: id)
    }
    
    @objc func validateId(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(type: type, id: ioValue.pointee as! Int)
    }
    
    private func checkConflict(type: String, id: Int) throws {
        if (type != self.type || id != self.id) && (document as? ResourceDocument)?.directory.findResource(type: type, id: id) != nil {
            throw ResourceError.conflict(type, id)
        }
    }
}

enum ResourceError: LocalizedError {
    case conflict(String, Int)
    var errorDescription: String? {
        switch self {
        case let .conflict(type, id):
            return String(format: NSLocalizedString("A resource of type ‘%@’ with ID %ld already exists.", comment: ""), type, id)
        }
    }
    var recoverySuggestion: String? {
        switch self {
        case .conflict(_, _):
            return String(format: NSLocalizedString("Please enter a unique value.", comment: ""))
        }
    }
}
