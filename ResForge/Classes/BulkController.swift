import Cocoa
import CreateML
import RFSupport

enum BulkError: LocalizedError {
    case templateError(Error)
    case templateNotFound(ResourceType)
    case invalidValue(String, Int)
    case missingValue(String, Int)
    
    var errorDescription: String? {
        switch self {
        case .templateError:
            return NSLocalizedString("Invalid basic template.", comment: "")
        case let .templateNotFound(type):
            return String(format: NSLocalizedString("Could not find ‘%@’ resource for type ‘%@’.", comment: ""), PluginRegistry.basicTemplateType.code, type.code)
        case let .invalidValue(column, row):
            return String(format: NSLocalizedString("Invalid value for “%@” on row %d.", comment: ""), column, row)
        case let .missingValue(column, row):
            return String(format: NSLocalizedString("Missing value for “%@” on row %d.", comment: ""), column, row)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case let .templateError(error):
            return error.localizedDescription
        default:
            return nil
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
    
    @IBAction func doubleClickItems(_ sender: Any) {
        // Ignore double-clicks in table header
        guard outlineView.clickedRow != -1 else {
            return
        }
        if outlineView.clickedColumn == -1 || outlineView.tableColumns[outlineView.clickedColumn] == idCol {
            document.openResources(sender)
        } else {
            outlineView.editColumn(outlineView.clickedColumn, row: outlineView.clickedRow, with: nil, select: false)
        }
    }
    
    override func prepareView(type: ResourceType!) throws -> NSView {
        try self.loadTemplate(type: type)
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
    
    func loadTemplate(type: ResourceType) throws {
        guard let template = document.editorManager.template(for: type, basic: true) else {
            throw BulkError.templateNotFound(type)
        }
        do {
            elements = try PluginRegistry.templateEditor.parseBasicTemplate(template, manager: document.editorManager)
        } catch let error {
            throw BulkError.templateError(error)
        }
        currentType = type
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
        let resources = document.directory.resources(ofType: currentType!)
        table.addColumn(MLDataColumn(resources.map(\.id)), named: "ID")
        table.addColumn(MLDataColumn(resources.map(\.name)), named: "Name")
        let rows = resources.map(self.read(resource:))
        for (i, element) in elements.enumerated() where element.visible {
            let column = rows.map { element.formatter!.string(for: $0[i])! }
            table.addColumn(MLDataColumn(column), named: element.displayLabel)
        }
        try table.writeCSV(to: url)
    }
    
    func importCSV(from url: URL) throws -> [Resource] {
        guard #available(OSX 10.14, *) else {
            return []
        }
        var resources: [Resource] = []
        let table = try MLDataTable(contentsOf: url, options: MLDataTable.ParsingOptions(skipInitialSpaces: false, missingValues: []))
        for (i, row) in table.rows.enumerated() {
            guard let id = row["ID"]?.intValue else {
                throw BulkError.invalidValue("ID", i)
            }
            guard let name = row["Name"]?.stringValue else {
                throw BulkError.invalidValue("Name", i)
            }
            let resource = Resource(type: currentType!, id: id, name: name)
            let writer = BinaryDataWriter()
            for element in elements {
                if element.visible {
                    let string: String
                    switch row[element.displayLabel] {
                    case nil:
                        throw BulkError.missingValue(element.displayLabel, i)
                    case let .string(v):
                        string = v
                    case let .int(v):
                        string = String(v)
                    case let .double(v):
                        string = String(v)
                    default:
                        string = ""
                    }
                    var error: NSString?
                    var value: AnyObject?
                    guard element.formatter!.getObjectValue(&value, for: string, errorDescription: &error) else {
                        throw BulkError.invalidValue(element.displayLabel, i)
                    }
                    element.setValue(value, forKey: "value")
                }
                element.writeData(to: writer)
            }
            resource.data = writer.data
            resources.append(resource)
        }
        return resources
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
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let resource = item as! Resource
        if tableColumn == idCol {
            return String(resource.id)
        } else if tableColumn == nameCol {
            return resource.name
        } else if let tableColumn = tableColumn {
            let rowData = rows[resource.id] ?? self.read(resource: resource)
            rows[resource.id] = rowData
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
