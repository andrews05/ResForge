import Cocoa
import OrderedCollections
import RFSupport

enum ConflictResolution {
    case unique
    case replace
    case skip
}

class ConflictResolver {
    private(set) var toAdd: [Resource] = []
    private(set) var toRemove: [Resource] = []
    private let document: ResourceDocument
    private let multiple: Bool
    private var resolution: ConflictResolution?
    private lazy var alert: NSAlert = {
        let alert = NSAlert()
        alert.informativeText = NSLocalizedString("Do you wish to assign the new resource a unique ID, replace the existing resource, or skip this resource?", comment: "")
        alert.addButton(withTitle: NSLocalizedString("Unique ID", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Replace", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Skip", comment: ""))
        alert.suppressionButton?.title = NSLocalizedString("Apply to all", comment: "")
        return alert
    }()

    init(document: ResourceDocument, multiple: Bool) {
        self.document = document
        self.multiple = multiple
    }

    func process(type: ResourceType, resources: [Resource]) {
        guard let existing = document.directory.resourceMap[type] else {
            toAdd.append(contentsOf: resources)
            return
        }
        // Keep an ordered mapping of ids to resources to allow us to quickly find both conflicts and unique ids
        var idMap = existing.reduce(into: OrderedDictionary()) { $0[$1.id] = $1 }
        for resource in resources {
            if let conflicted = idMap[resource.id] {
                switch resolution ?? self.getResolution(for: conflicted) {
                case .unique:
                    var index = idMap.index(forKey: conflicted.id)!
                    resource.id = document.directory.nextAvailableID(in: idMap.keys, startingAt: &index)
                    idMap.updateValue(resource, forKey: resource.id, insertingAt: index)
                case .replace:
                    toRemove.append(conflicted)
                case .skip:
                    continue
                }
            } else {
                idMap.insert(key: resource.id, value: resource) { $0 < $1 }
            }
            toAdd.append(resource)
        }
    }

    private func getResolution(for conflicted: Resource) -> ConflictResolution {
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
        if alert.suppressionButton?.state == .on {
            self.resolution = resolution
        }
        return resolution
    }
}
