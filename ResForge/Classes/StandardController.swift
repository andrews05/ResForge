import Cocoa
import RFSupport

class StandardController: OutlineController {
    @IBAction func doubleClickItems(_ sender: Any) {
        // Ignore double-clicks in table header
        guard outlineView.clickedRow != -1 else {
            return
        }
        for item in outlineView.selectedItems where item is ResourceType {
            // Expand the type list
            outlineView.expandItem(item)
        }
        document.openResources(sender)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Default sort resources by id
        // Note: awakeFromNib is re-triggered each time a cell is created - be careful not to re-sort each time
        if outlineView.sortDescriptors.isEmpty, let descriptor = outlineView.outlineTableColumn?.sortDescriptorPrototype {
            outlineView.sortDescriptors = [descriptor]
        }
    }

    override func prepareView(type: ResourceType?) -> NSView {
        currentType = type
        outlineView.indentationPerLevel = type == nil ? 1 : 0
        outlineView.tableColumns[0].width = type == nil ? 76 : 66
        self.setSorter()
        return outlineView
    }

    override func updated(resource: Resource, oldIndex: Int?) {
        // Always return first responder to the outlineView, e.g. in case of inline editing
        document.dataSource.ignoreChanges = true
        outlineView.window?.makeFirstResponder(outlineView)
        document.dataSource.ignoreChanges = false

        let parent = currentType == nil ? resource.type : nil
        let newIndex = document.directory.filteredResources(type: resource.type).firstIndex(of: resource)
        self.updateRow(oldIndex: oldIndex, newIndex: newIndex, parent: parent)
        if outlineView.selectedItem as? Resource == resource {
            outlineView.scrollRowToVisible(outlineView.selectedRow)
        }
        outlineView.reloadItem(resource)
    }

    // MARK: - Delegate functions

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view: NSTableCellView
        if let resource = item as? Resource {
            view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
            switch tableColumn!.identifier.rawValue {
            case "id":
                view.textField?.integerValue = resource.id
                view.imageView?.image = resource.statusIcon()
            case "name":
                view.textField?.bind(.value, to: resource, withKeyPath: "name")
                view.textField?.placeholderString = resource.placeholderName()
            case "size":
                view.textField?.integerValue = resource.data.count
            default:
                return nil
            }
            return view
        } else if let type = item as? ResourceType {
            let identifier = "\(tableColumn!.identifier.rawValue)Group"
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as! NSTableCellView
            switch identifier {
            case "idGroup":
                view.textField?.stringValue = type.code
            case "nameGroup":
                view.textField?.stringValue = type.attributesDisplay
            case "sizeGroup":
                view.textField?.integerValue = document.directory.resourceMap[type]!.count
            default:
                return nil
            }
            return view
        }
        return nil
    }
}
