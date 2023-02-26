import Foundation
import RFSupport

// Extend the Resource class to validate type and id by checking for conflicts
extension Resource {
    @objc func validateTypeCode(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(typeCode: ioValue.pointee as? String)
    }
    
    @objc func validateTypeAttributes(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(typeAttributes: ioValue.pointee as? [String: String])
    }
    
    @objc func validateId(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(id: ioValue.pointee as? Int)
    }
    
    func checkConflict(typeCode: String? = nil, typeAttributes: [String: String]? = nil, id: Int? = nil) throws {
        let type = ResourceType(typeCode ?? self.typeCode, typeAttributes ?? self.typeAttributes)
        let id = id ?? self.id
        if (type != self.type || id != self.id) && (document as? ResourceDocument)?.directory.findResource(type: type, id: id) != nil {
            throw ResourceError.conflict(type, id)
        }
    }
    
    // Used for formatter binding
    @objc var minID: Int {
        (document as? ResourceDocument)?.format.minID ?? 0
    }
    @objc var maxID: Int {
        (document as? ResourceDocument)?.format.maxID ?? 0
    }
    
    // If the revision doesn't match the document's then the resource was not present at last save and is therefore "new"
    var isNew: Bool {
        _revision != (document as? ResourceDocument)?.revision
    }
}

enum ResourceError: LocalizedError {
    case conflict(ResourceType, Int)
    var errorDescription: String? {
        switch self {
        case let .conflict(type, id):
            return String(format: NSLocalizedString("A resource of type ‘%@’ with ID %ld already exists.", comment: ""), type.code, id)
        }
    }
    var recoverySuggestion: String? {
        switch self {
        case .conflict(_, _):
            return String(format: NSLocalizedString("Please enter a unique value.", comment: ""))
        }
    }
}
