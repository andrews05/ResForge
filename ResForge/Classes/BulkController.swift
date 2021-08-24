import Cocoa
import RFSupport

class BulkController: OutlineController {
    private var elements: [TemplateField] = []
    private var resource: Resource!
    private var rowData: [Any?] = []
    private let idCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    
    init?(document: ResourceDocument) {
        guard let type = document.dataSource.currentType,
              let template = document.editorManager.findResource(type: ResourceType("TMPS"), name: type.code)
        else {
            return nil
        }
        do {
            elements = try PluginRegistry.templateEditor.parseSimpleTemplate(template, manager: document.editorManager)
        } catch {
            return nil
        }
        
        super.init()
        self.outlineView = NSOutlineView(frame: NSMakeRect(0, 0, 500, 500))
        self.document = document
        self.dataSource = document.dataSource
        
        idCol.headerCell.title = "ID"
        idCol.width = 60
        outlineView.addTableColumn(idCol)
        nameCol.headerCell.title = "Name"
        nameCol.width = 150
        outlineView.addTableColumn(nameCol)
        for (i, element) in elements.enumerated() where element.visible {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(i)))
            column.headerCell.title = element.displayLabel
            column.width = element.width == 0 ? 150 : min(element.width, 150)
            outlineView.addTableColumn(column)
        }
        outlineView.indentationPerLevel = 0
        outlineView.rowHeight = 19
        outlineView.usesAlternatingRowBackgroundColors = true
        outlineView.allowsMultipleSelection = true
        outlineView.focusRingType = .none
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.target = self
        outlineView.doubleAction = #selector(doubleClickItems(_:))
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
    
    override func updated(resource: Resource, oldIndex: Int, newIndex: Int) {
        if !inlineUpdate {
            outlineView.beginUpdates()
            outlineView.moveItem(at: oldIndex, inParent: nil, to: newIndex, inParent: nil)
            outlineView.endUpdates()
        }
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
        inlineUpdate = true
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
        inlineUpdate = false
    }
}
