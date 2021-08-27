import Cocoa
import CreateML
import RFSupport

enum BulkError: LocalizedError {
    case templateError(Error)
    
    var errorDescription: String? {
        switch self {
        case .templateError:
            return NSLocalizedString("Invalid basic template.", comment: "")
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
    private var defaults: [Any?] = []
    private var rows: [Int: [Any?]] = [:]
    private let idCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    
    init(document: ResourceDocument) {
        super.init()
        self.outlineView = NSOutlineView(frame: NSMakeRect(0, 0, 500, 500))
        self.document = document
        self.dataSource = document.dataSource
        
        idCol.headerCell.title = "ID"
        idCol.width = 58
        nameCol.headerCell.title = "Name"
        nameCol.width = 150
        outlineView.addTableColumn(idCol)
        outlineView.addTableColumn(nameCol)
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
    
    override func prepareView() throws -> NSView {
        try self.loadTemplate()
        for column in outlineView.tableColumns {
            if column != idCol && column != nameCol {
                outlineView.removeTableColumn(column)
            }
        }
        for (i, element) in elements.enumerated() where element.visible {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(i)))
            column.headerCell.title = element.displayLabel
            column.width = element.width == 0 ? 150 : min(element.width, 150)
            outlineView.addTableColumn(column)
        }
        document.directory.sortDescriptors = []
        return outlineView
    }
    
    override func reload() {
        rows.removeAll()
        outlineView.reloadData()
    }
    
    override func updated(resource: Resource, oldIndex: Int?) {
        let newIndex = document.directory.filteredResources(type: resource.type).firstIndex(of: resource)
        if !inlineUpdate || newIndex == nil {
            rows.removeValue(forKey: resource.id)
            outlineView.beginUpdates()
            self.updateRow(oldIndex: oldIndex, newIndex: newIndex, parent: nil)
            outlineView.endUpdates()
        }
    }
    
    func loadTemplate() throws {
        guard let template = document.editorManager.template(for: dataSource.currentType, basic: true) else {
            return
        }
        do {
            elements = try PluginRegistry.templateEditor.parseBasicTemplate(template, manager: document.editorManager)
        } catch let error {
            throw BulkError.templateError(error)
        }
        defaults = elements.map {
            $0.visible ? $0.value(forKey: "value") : nil
        }
    }
    
    func exportCSV(to url: URL) throws {
        guard #available(OSX 10.14, *) else {
            return
        }
        // MLDataTable is an easy built-in option for working with csv
        var table = MLDataTable()
        let rows = document.directory.resources(ofType: dataSource.currentType!).map(self.read(resource:))
        for (i, element) in elements.enumerated() where element.visible {
            let column = rows.map { element.formatter!.string(for: $0[i])! }
            table.addColumn(MLDataColumn(column), named: element.displayLabel)
        }
        try table.writeCSV(to: url)
    }
    
    private func read(resource: Resource) -> [Any?] {
        let reader = BinaryDataReader(resource.data)
        return elements.enumerated().map { (i, element) in
            do {
                try element.readData(from: reader)
                return element.visible ? element.value(forKey: "value") : nil
            } catch {
                // Insufficient data, set a default value
                return defaults[i]
            }
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
            return String(resource.id)
        } else if tableColumn == nameCol {
            return resource.name
        } else if let tableColumn = tableColumn {
            let rowData = rows[resource.id] ?? self.read(resource: resource)
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
            rows[resource.id]![Int(tableColumn.identifier.rawValue)!] = object
            let rowData = rows[resource.id]!
            let writer = BinaryDataWriter()
            for (i, element) in elements.enumerated() {
                if element.visible {
                    element.setValue(rowData[i], forKey: "value")
                }
                element.writeData(to: writer)
            }
            resource.data = writer.data
        }
        inlineUpdate = false
    }
}
