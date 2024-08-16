import AppKit
import RFSupport

extension Resource {
    // MARK: - Attribute bindings

    @objc var isChanged: Bool {
        get { attributes.contains(.changed) }
        set { attributes.formSymmetricDifference(.changed) }
    }

    @objc var isPreload: Bool {
        get { attributes.contains(.preload) }
        set { attributes.formSymmetricDifference(.preload) }
    }

    @objc var isProtected: Bool {
        get { attributes.contains(.protected) }
        set { attributes.formSymmetricDifference(.protected) }
    }

    @objc var isLocked: Bool {
        get { attributes.contains(.locked) }
        set { attributes.formSymmetricDifference(.locked) }
    }

    @objc var isPurgeable: Bool {
        get { attributes.contains(.purgeable) }
        set { attributes.formSymmetricDifference(.purgeable) }
    }

    @objc var isSysHeap: Bool {
        get { attributes.contains(.sysHeap) }
        set { attributes.formSymmetricDifference(.sysHeap) }
    }

    public override class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String> {
        switch key {
        case "isChanged", "isPreload", "isProtected", "isLocked", "isPurgeable", "isSysHeap":
            return ["attributes"]
        default:
            return []
        }
    }

    // MARK: - Type/ID Validation

    @objc func validateTypeCode(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(typeCode: ioValue.pointee as? String)
    }

    @objc func validateTypeAttributes(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        try self.checkConflict(typeAttributes: ioValue.pointee as? [String: String])
    }

    @objc func validateId(_ ioValue: AutoreleasingUnsafeMutablePointer<AnyObject?>) throws {
        let id = ioValue.pointee as? Int
        if let id, (document as? ResourceDocument)?.format.isValid(id: id) != true {
            throw ResourceError.invalidID(id)
        }
        try self.checkConflict(id: id)
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

    var isPropertiesModified: Bool {
        _state.type != nil ||
        _state.id != nil ||
        _state.name != nil ||
        _state.attributes != nil
    }

    var isDataModified: Bool {
        _state.data != nil
    }

    /// Reset the tracked state.
    func resetState() {
        _state.type = nil
        _state.id = nil
        _state.name = nil
        _state.data = nil
        _state.revision = (document as? ResourceDocument)?.revision
    }

    /// Revert data to last saved state.
    func revertData() {
        if let data = _state.data {
            self.data = data
        }
    }

    /// Returns an icon indicating the resource's current status.
    func statusIcon() -> NSImage? {
        let color: NSColor
        if isNew {
            color = NSColor(red: 0.156, green: 0.803, blue: 0.256, alpha: 1)
        } else if isDataModified {
            // Data modified takes precedence over properties modified
            color = NSColor(red: 0.265, green: 0.615, blue: 0.997, alpha: 1)
        } else if isPropertiesModified {
            color = NSColor(red: 0.999, green: 0.665, blue: 0.277, alpha: 1)
        } else {
            return nil
        }
        return NSImage(size: NSSize(width: 9, height: 9), flipped: false) {
            color.set()
            NSBezierPath(ovalIn: $0).fill()
            return true
        }
    }
}

enum ResourceError: LocalizedError {
    case conflict(ResourceType, Int)
    case invalidID(Int)

    var errorDescription: String? {
        switch self {
        case let .conflict(type, id):
            return String(format: NSLocalizedString("A resource of type ‘%@’ with ID %ld already exists.", comment: ""), type.code, id)
        case let .invalidID(id):
            if id < 0 {
                return String(format: NSLocalizedString("The ID %ld is below the minimum value.", comment: ""), id)
            } else {
                return String(format: NSLocalizedString("The ID %ld is above the maximum value.", comment: ""), id)
            }
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .conflict:
            return NSLocalizedString("Please enter a unique value.", comment: "")
        case .invalidID:
            return NSLocalizedString("Please enter a valid value.", comment: "")
        }
    }
}
