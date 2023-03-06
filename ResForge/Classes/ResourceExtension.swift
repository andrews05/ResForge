import Foundation
import RFSupport

extension Resource {
    // Used for formatter binding
    @objc var minID: Int {
        (document as? ResourceDocument)?.format.minID ?? 0
    }
    @objc var maxID: Int {
        (document as? ResourceDocument)?.format.maxID ?? 0
    }
    
    // MARK: - Type/ID Validation
    
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
    
    // MARK: - State Tracking
    
    // If the revision doesn't match the document's then the resource was not present at last save and is therefore "new"
    var isNew: Bool {
        _state.revision != (document as? ResourceDocument)?.revision
    }
    
    // For basic properties, check if the value is actually different from the original
    var isPropertiesModified: Bool {
        (_state.type != nil && _state.type != type) ||
        (_state.id != nil && _state.id != id) ||
        (_state.name != nil && _state.name != name)
    }
    
    // For data, only check if the value was ever changed
    var isDataModified: Bool {
        _state.data != nil
    }
    
    /// Reset the tracked state.
    public func resetState() {
        _state.type = nil
        _state.id = nil
        _state.name = nil
        _state.data = nil
        _state.revision = (document as? ResourceDocument)?.revision
    }
    
    /// Revert data to last saved state.
    public func revertData() {
        if let data = _state.data {
            _state.disableTracking = true
            _state.data = nil
            self.data = data
            _state.disableTracking = false
        }
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
