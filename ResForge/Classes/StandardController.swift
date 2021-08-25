import Cocoa
import RFSupport

class StandardController: OutlineController, NSTextFieldDelegate {
    override func awakeFromNib() {
        super.awakeFromNib()
        // Default sort resources by id
        // Note: awakeFromNib is re-triggered each time a cell is created - be careful not to re-sort each time
        if outlineView.sortDescriptors.isEmpty {
            outlineView.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        }
    }
    
    override func prepareView() -> NSView {
        let typed = dataSource.currentType != nil
        outlineView.indentationPerLevel = typed ? 0 : 1
        outlineView.tableColumns[0].width = typed ? 60 : 70
        document.directory.sortDescriptors = outlineView.sortDescriptors
        return outlineView
    }
    
    override func updated(resource: Resource, oldIndex: Int?) {
        let parent = dataSource.currentType == nil ? resource.type : nil
        let newIndex = document.directory.filteredResources(type: resource.type).firstIndex(of: resource)
        if inlineUpdate {
            // The resource has been edited inline, perform the move async to ensure the first responder has been properly updated
            DispatchQueue.main.async { [self] in
                self.updateRow(oldIndex: oldIndex, newIndex: newIndex, parent: parent)
                outlineView.scrollRowToVisible(outlineView.selectedRow)
            }
        } else {
            self.updateRow(oldIndex: oldIndex, newIndex: newIndex, parent: parent)
            outlineView.reloadItem(resource)
        }
    }
    
    // MARK: - Delegate functions
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view: NSTableCellView
        if let resource = item as? Resource {
            view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
            switch tableColumn!.identifier.rawValue {
            case "id":
                view.textField?.integerValue = resource.id
            case "name":
                view.textField?.stringValue = resource.name
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
                view.textField?.integerValue = document.directory.resourcesByType[type]!.count
            default:
                return nil
            }
            return view
        }
        return nil
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        let textField = obj.object as! NSTextField
        guard let resource = outlineView.item(atRow: outlineView.row(for: textField)) as? Resource else {
            // This can happen if the resource was updated by some other means while the field was in edit mode
            return
        }
        // We don't need to reload the item after changing values here
        inlineUpdate = true
        switch textField.identifier?.rawValue {
        case "name":
            resource.name = textField.stringValue
        default:
            break
        }
        inlineUpdate = false
    }
    
    // MARK: - DataSource functions
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let type = item as? ResourceType ?? dataSource.currentType {
            return document.directory.filteredResources(type: type)[index]
        } else {
            return document.directory.filteredTypes()[index]
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let type = item as? ResourceType ?? dataSource.currentType {
            return document.directory.filteredResources(type: type).count
        } else {
            return document.directory.filteredTypes().count
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        document.directory.sortDescriptors = outlineView.sortDescriptors
        outlineView.reloadData()
    }
}
