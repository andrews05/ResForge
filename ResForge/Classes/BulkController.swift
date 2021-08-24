import Cocoa
import RFSupport

class BulkController: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource {
    private var resources: [Resource] = []
    private var elements: [TemplateField] = []
    private var resource: Resource!
    private var rowData: [Any?] = []
    private(set) var table = NSOutlineView(frame: NSMakeRect(0, 0, 500, 500))
    private let idCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    
    init?(type: ResourceType, manager: RFEditorManager) {
        guard let template = manager.findResource(type: ResourceType("TMPS"), name: type.code, currentDocumentOnly: false) else {
            return nil
        }
        do {
            elements = try PluginRegistry.templateEditor.parseSimpleTemplate(template, manager: manager)
        } catch {
            return nil
        }
        super.init()
        resources = manager.allResources(ofType: type, currentDocumentOnly: true)
        idCol.headerCell.title = "ID"
        idCol.width = 60
        table.addTableColumn(idCol)
        nameCol.headerCell.title = "Name"
        nameCol.width = 150
        table.addTableColumn(nameCol)
        for (i, element) in elements.enumerated() where element.visible {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(i)))
            column.headerCell.title = element.displayLabel
            column.width = element.width == 0 ? 150 : min(element.width, 150)
            table.addTableColumn(column)
        }
        table.indentationPerLevel = 0
        table.rowHeight = 19
        table.usesAlternatingRowBackgroundColors = true
        table.delegate = self
        table.dataSource = self
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return resources.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return resources[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        guard let cell = cell as? NSTextFieldCell else {
            return
        }
        if tableColumn == idCol {
            cell.alignment = .right
        } else if tableColumn == nameCol {
            let formatter = MacRomanFormatter()
            formatter.stringLength = 255
            cell.formatter = formatter
        } else if let tableColumn = tableColumn {
            let element = elements[Int(tableColumn.identifier.rawValue)!]
            cell.formatter = element.formatter
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
        return tableColumn != idCol
    }
    
    private func load(resource: Resource) {
        if resource !== self.resource {
            self.resource = resource
            let reader = BinaryDataReader(resource.data)
            rowData.removeAll()
            for element in elements {
                try? element.readData(from: reader)
                rowData.append(element.visible ? element.value(forKey: "value") : nil)
            }
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let resource = item as! Resource
        if tableColumn == idCol {
            return resource.id
        } else if tableColumn == nameCol {
            return resource.name
        } else if let tableColumn = tableColumn {
            self.load(resource: resource)
            return rowData[Int(tableColumn.identifier.rawValue)!]
        }
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, byItem item: Any?) {
        let resource = item as! Resource
        if tableColumn == nameCol {
            resource.name = object as! String
        } else if let tableColumn = tableColumn {
            self.load(resource: resource)
            let column = Int(tableColumn.identifier.rawValue)!
            rowData[column] = object
            elements[column].setValue(object, forKey: "value")
            let writer = BinaryDataWriter()
            for element in elements {
                element.writeData(to: writer)
            }
            resource.data = writer.data
        }
    }
    
//    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
//        if rowData[row] == nil {
//            let reader = BinaryDataReader(resources[row].data)
//            var values: [Any] = []
//            for element in elements {
//                try? element.readData(from: reader)
//                let value = element.value(forKey: "value")!
//                values.append(value)
//            }
//            rowData[row] = values
//        }
//        let i = Int(tableColumn!.identifier.rawValue)!
//        let view = NSTextField()
//        view.objectValue = rowData[row]![i]
//        view.formatter = elements[i].formatter
//        return view
//    }
}
