import Cocoa
import RFSupport

class StandardController: OutlineController, NSTextFieldDelegate {
    static let Color_New = NSColor(red: 0.156, green: 0.803, blue: 0.256, alpha: 1)
    static let Color_AttributesModified = NSColor(red: 1, green: 0.582, blue: 0, alpha: 1)
    static let Color_DataModified = NSColor(red: 0.333, green: 0.746, blue: 0.942, alpha: 1)
    
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
        outlineView.tableColumns[0].width = type == nil ? 70 : 60
        self.setSorter()
        return outlineView
    }
    
    override func updated(resource: Resource, oldIndex: Int?) {
        let parent = currentType == nil ? resource.type : nil
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
                if resource.isNew {
                    view.imageView?.image = NSImage(named: "NSMenuItemBullet")!.tint(color: Self.Color_New)
                } else {
                    view.imageView?.image = nil
                }
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
}

extension NSImage {
    func tint(color: NSColor) -> NSImage {
        return NSImage(size: size, flipped: false) { (rect) -> Bool in
            color.set()
            rect.fill()
            self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .destinationIn, fraction: 1.0)
            return true
        }
    }
}
