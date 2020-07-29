import Foundation
import RKSupport

class OutlineViewDelegate: NSObject, NSOutlineViewDelegate {
    @IBOutlet var outlineView: NSOutlineView!
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlaceholder(_:)), name: .ResourceTypeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updatePlaceholder(_:)), name: .ResourceIDDidChange, object: nil)
    }
    
    @objc func updatePlaceholder(_ notification: Notification) {
        let resource = notification.object as! Resource
        if (resource.document as! ResourceDocument).outlineView() === outlineView {
            let column = outlineView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "name"))
            let cell = column?.dataCell(forRow: outlineView.row(forItem: resource)) as! NSTextFieldCell
            cell.placeholderString = self.placeholder(for: resource)
        }
    }
    
    func placeholder(for resource: Resource) -> String {
        if resource.resID == -16455 {
            // don't bother checking type since there are too many icon types
            return NSLocalizedString("Custom Icon", comment: "")
        }
        
        switch resource.type {
        case "carb":
            if resource.resID == 0 {
                return NSLocalizedString("Carbon Identifier", comment: "")
            }
        case "pnot":
            if resource.resID == 0 {
                return NSLocalizedString("File Preview", comment: "")
            }
        case "STR ":
            if resource.resID == -16396 {
                return NSLocalizedString("Creator Information", comment: "")
            }
        case "vers":
            if resource.resID == 1 {
                return NSLocalizedString("File Version", comment: "")
            } else if resource.resID == 2 {
                return NSLocalizedString("Package Version", comment: "")
            }
        default:
            return NSLocalizedString("Untitled Resource", comment: "")
        }
        return ""
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
        return (item as? Resource) != nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        if tableColumn?.identifier.rawValue == "name" {
            let cell = cell as! ResourceNameCell
            if let resource = item as? Resource {
                // set resource icon
                cell.drawImage = true
                cell.image = ApplicationDelegate.icon(for: resource.type)
                cell.placeholderString = self.placeholder(for: resource)
            } else {
                cell.drawImage = false
            }
        }
    }
}
