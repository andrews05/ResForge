import Cocoa
import RFSupport

enum BulkError: LocalizedError {
    case templateError(Error)
    
    var errorDescription: String? {
        switch self {
        case .templateError:
            return NSLocalizedString("Invalid simple template.", comment: "")
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .templateError(let e):
            return e.localizedDescription
        }
    }
}

class BulkController: OutlineController {
    private var elements: [TemplateField] = []
    private var resource: Resource!
    private var rowData: [Any?] = []
    private let idCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    
    init(document: ResourceDocument) throws {
        let template = document.editorManager.findResource(type: PluginRegistry.simpleTemplateType,
                                                           name: document.dataSource.currentType!.code)!
        
        do {
            elements = try PluginRegistry.templateEditor.parseSimpleTemplate(template, manager: document.editorManager)
        } catch let error {
            throw BulkError.templateError(error)
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
        outlineView.rowHeight = 17
        outlineView.intercellSpacing = NSSize(width: 7, height: 2)
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
    
    override func prepareView() -> NSView {
        document.directory.sortDescriptors = []
        return outlineView
    }
    
    override func updated(resource: Resource, oldIndex: Int?) {
        let newIndex = document.directory.filteredResources(type: resource.type).firstIndex(of: resource)
        if !inlineUpdate || newIndex == nil {
            outlineView.beginUpdates()
            self.updateRow(oldIndex: oldIndex, newIndex: newIndex, parent: nil)
            outlineView.endUpdates()
        }
    }
    
    // MARK: - Delegate functions
    
    func outlineView(_ outlineView: NSOutlineView, willDisplayCell cell: Any, for tableColumn: NSTableColumn?, item: Any) {
        guard let cell = cell as? NSTextFieldCell else {
            return
        }
        if tableColumn == idCol {
            cell.alignment = .right
            cell.isEditable = false
        } else if tableColumn == nameCol {
            let formatter = MacRomanFormatter()
            formatter.stringLength = 255
            cell.formatter = formatter
            cell.placeholderString = NSLocalizedString("Untitled Resource", comment: "")
        } else if let tableColumn = tableColumn {
            let element = elements[Int(tableColumn.identifier.rawValue)!]
            cell.formatter = element.formatter
        }
    }
    
    // MARK: - Data Source functions
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return document.directory.filteredResources(type: dataSource.currentType!)[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return document.directory.filteredResources(type: dataSource.currentType!).count
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
