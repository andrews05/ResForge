import Cocoa
import CSV
import RFSupport

enum BulkError: LocalizedError {
    case templateError(Error)
    case templateNotFound(ResourceType)
    case invalidValue(String, Int, String?=nil)

    var errorDescription: String? {
        switch self {
        case .templateError:
            return NSLocalizedString("Invalid basic template.", comment: "")
        case let .templateNotFound(type):
            return String(format: NSLocalizedString("Could not find ‘%@’ resource for type ‘%@’.", comment: ""), ResourceType.BasicTemplate.code, type.code)
        case let .invalidValue(column, row, _):
            return String(format: NSLocalizedString("Invalid value for “%@” on row %d.", comment: ""), column, row)
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case let .templateError(error):
            return error.localizedDescription
        case let .invalidValue(_, _, message):
            return message
        default:
            return nil
        }
    }
}

class BulkController: OutlineController {
    private var elements: [BaseElement] = []
    private var defaults: [Any?] = []
    private var rows: [Int: [Any?]] = [:]
    private let idCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("id"))
    private let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))

    init(document: ResourceDocument) {
        super.init()
        self.outlineView = NSOutlineView(frame: NSRect(x: 0, y: 0, width: 500, height: 500))
        self.document = document

        idCol.headerCell.title = "ID"
        idCol.width = 64
        idCol.sortDescriptorPrototype = NSSortDescriptor(key: "id", ascending: true)
        idCol.isEditable = false
        nameCol.headerCell.title = "Name"
        nameCol.width = 150
        nameCol.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedStandardCompare(_:)))
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
            outlineView.editColumn(outlineView.clickedColumn, row: outlineView.clickedRow, with: nil, select: true)
        }
    }

    override func prepareView(type: ResourceType!) throws -> NSView {
        try self.loadTemplate(type: type)
        for column in outlineView.tableColumns {
            if column != idCol && column != nameCol {
                outlineView.removeTableColumn(column)
            }
        }
        for case let (i, element as FormattedElement) in elements.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(String(i)))
            column.headerCell.title = element.displayLabel
            column.sizeToFit()
            column.width = max(min(element.width, 150), column.width)
            column.sortDescriptorPrototype = NSSortDescriptor(key: String(i), ascending: true)
            outlineView.addTableColumn(column)
        }
        outlineView.sortDescriptors = [idCol.sortDescriptorPrototype!]
        document.directory.sorter = nil
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
        }
        if oldIndex != newIndex {
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
            elements = try TemplateParser(template: template, manager: document.editorManager, basic: true).parse()
        } catch let error {
            throw BulkError.templateError(error)
        }
        currentType = type
        defaults = elements.map {
            ($0 as? FormattedElement)?.defaultValue()
        }
    }

    func exportCSV(to url: URL) throws {
        let resources = document.directory.resources(ofType: currentType!)
        let writer = try CSVWriter(stream: OutputStream(url: url, append: false)!)
        let headers = elements.compactMap {
            ($0 as? FormattedElement)?.displayLabel
        }
        try writer.write(row: ["ID", "Name"] + headers)
        for resource in resources {
            let data: [String] = self.read(resource: resource).enumerated().compactMap { (i, value) in
                (elements[i] as? FormattedElement)?.formatter.string(for: value)
            }
            try writer.write(row: [String(resource.id), resource.name] + data)
        }
        writer.stream.close()
    }

    func importCSV(from url: URL) throws -> [Resource] {
        var resources: [Resource] = []
        let record = try CSVReader(stream: InputStream(url: url)!, hasHeaderRow: true)
        var i = 1
        while record.next() != nil {
            guard let v = record["ID"], let id = Int(v), document.format.isValid(id: id)  else {
                throw BulkError.invalidValue("ID", i)
            }
            guard let name = record["Name"] else {
                throw BulkError.invalidValue("Name", i)
            }
            let resource = Resource(type: currentType!, id: id, name: name)
            let writer = BinaryDataWriter()
            for element in elements {
                if let element = element as? FormattedElement {
                    guard let string = record[element.displayLabel] else {
                        throw BulkError.invalidValue(element.displayLabel, i)
                    }
                    do {
                        let value = try element.formatter.getObjectValue(for: string)
                        element.setValue(value, forKey: "value")
                    } catch let error {
                        throw BulkError.invalidValue(element.displayLabel, i, error.localizedDescription)
                    }
                }
                element.writeData(to: writer)
            }
            resource.data = writer.data
            resources.append(resource)
            i += 1
        }
        return resources
    }

    private func read(resource: Resource) -> [Any?] {
        let reader = BinaryDataReader(resource.data)
        return elements.enumerated().map { (i, element) in
            do {
                try element.readData(from: reader)
                return (element as? FormattedElement)?.value(forKey: "value")
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
        } else if tableColumn == nameCol {
            let formatter = MacRomanFormatter()
            formatter.stringLength = 255
            cell.formatter = formatter
            cell.placeholderString = NSLocalizedString("Untitled Resource", comment: "")
        } else if let tableColumn {
            let element = elements[Int(tableColumn.identifier.rawValue)!]
            cell.formatter = (element as? FormattedElement)?.formatter
        }
    }

    // MARK: - Data Source functions

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        let resource = item as! Resource
        if tableColumn == idCol {
            return String(resource.id)
        } else if tableColumn == nameCol {
            return resource.name
        } else if let tableColumn {
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
        } else if let tableColumn {
            rows[resource.id]![Int(tableColumn.identifier.rawValue)!] = object
            let rowData = rows[resource.id]!
            let writer = BinaryDataWriter()
            for (i, element) in elements.enumerated() {
                (element as? FormattedElement)?.setValue(rowData[i], forKey: "value")
                element.writeData(to: writer)
            }
            resource.data = writer.data
        }
        inlineUpdate = false
    }

    override func setSorter() {
        guard let descriptor = outlineView.sortDescriptors.first else {
            return
        }
        if descriptor == outlineView.outlineTableColumn?.sortDescriptorPrototype {
            document.directory.sorter = nil
        } else if descriptor.key == "id" || descriptor.key == "name" {
            document.directory.sorter = descriptor.compare
        } else if let key = descriptor.key {
            // Create a sorter function for the custom column
            let columnIdx = outlineView.column(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: key))
            let column = outlineView.tableColumns[columnIdx]
            let order: ComparisonResult = descriptor.ascending ? .orderedAscending : .orderedDescending
            document.directory.sorter = { [unowned self] in
                guard let a = self.outlineView(outlineView, objectValueFor: column, byItem: $0),
                      let b = self.outlineView(outlineView, objectValueFor: column, byItem: $1)
                else {
                    return false
                }
                if let a = a as? String, let b = b as? String {
                    return a.localizedStandardCompare(b) == order
                } else if let a = a as? NSNumber, let b = b as? NSNumber {
                    return a.compare(b) == order
                }
                return false
            }
        }
    }
}
