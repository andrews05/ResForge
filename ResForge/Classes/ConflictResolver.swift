import Cocoa
import RFSupport

enum ConflictResolution {
    case unique
    case replace
    case skip
}

class ConflictResolver {
    private let document: ResourceDocument
    private var resolution: ConflictResolution?
    private var alert = NSAlert()
    
    init(document: ResourceDocument) {
        self.document = document
        alert.informativeText = NSLocalizedString("Do you wish to assign the new resource a unique ID, overwrite the existing resource, or skip this resource?", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Unique ID", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Overwrite", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Skip", comment: ""))
        alert.suppressionButton?.title = NSLocalizedString("Apply to all", comment: "")
    }
    
    func resolve(_ resource: Resource, conflicted: Resource, multiple: Bool) -> Bool {
        if let resolution = resolution {
            return resolve(resource, conficted: conflicted, resolution: resolution)
        }
        alert.messageText = String(format: NSLocalizedString("A resource of type ‘%@’ with ID %ld already exists.", comment: ""), conflicted.typeCode, conflicted.id)
        alert.showsSuppressionButton = multiple
        // TODO: Do this in a non-blocking way?
        alert.beginSheetModal(for: document.windowForSheet!, completionHandler: NSApp.stopModal(withCode:))
        let modalResponse = NSApp.runModal(for: alert.window)
        let resolution: ConflictResolution
        switch modalResponse {
        case .alertFirstButtonReturn:
            resolution = .unique
        case .alertSecondButtonReturn:
            resolution = .replace
        default:
            resolution = .skip
        }
        if self.alert.suppressionButton?.state == .on {
            self.resolution = resolution
        }
        return self.resolve(resource, conficted: conflicted, resolution: resolution)
    }
    
    private func resolve(_ resource: Resource, conficted: Resource, resolution: ConflictResolution) -> Bool {
        switch resolution {
        case .unique:
            resource.id = document.directory.uniqueID(for: conficted.type, starting: conficted.id)
        case .replace:
            document.directory.remove(conficted)
        case .skip:
            return false
        }
        return true
    }
}
