import AppKit
import RFSupport

class OutlineController: NSObject, NSOutlineViewDelegate, NSOutlineViewDataSource, ResourcesView {
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet weak var document: ResourceDocument!
    var currentType: ResourceType?

    func prepareView(type: ResourceType?) throws -> NSView {
        currentType = type
        return scrollView
    }

    func reload() {
        outlineView.reloadData()
    }

    func select(_ resources: [Resource]) {
        let rows: [Int]
        if resources.count > 1, let currentType {
            // Fast path for bulk selection when showing a single type
            let filtered = document.directory.filteredResources(type: currentType)
            let indexMap = filtered.enumerated().reduce(into: [:]) {
                $0[$1.element] = $1.offset
            }
            rows = resources.compactMap { indexMap[$0] }
        } else {
            // When showing all types we have to use outlineView.row(forItem:) which is relatively slow
            rows = resources.compactMap {
                outlineView.expandItem($0.type)
                let i = outlineView.row(forItem: $0)
                return i == -1 ? nil : i
            }
        }
        let rowSet = IndexSet(rows)
        // Ensure notification gets posted even if selection doesn't actually change
        if rowSet == outlineView.selectedRowIndexes {
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        } else {
            outlineView.selectRowIndexes(rowSet, byExtendingSelection: false)
            outlineView.scrollRowToVisible(outlineView.selectedRow)
        }
    }

    func selectionCount() -> Int {
        return outlineView.numberOfSelectedRows
    }

    func selectedResources(deep: Bool = false) -> [Resource] {
        if currentType != nil {
            return outlineView.selectedItems as! [Resource]
        } else if deep {
            var resources: [Resource] = []
            for item in outlineView.selectedItems {
                if let item = item as? ResourceType {
                    resources += document.directory.resourceMap[item]!
                } else if let item = item as? Resource, !resources.contains(item) {
                    resources.append(item)
                }
            }
            return resources
        } else {
            return outlineView.selectedItems.compactMap({ $0 as? Resource })
        }
    }

    func selectedType() -> ResourceType? {
        if let currentType {
            return currentType
        } else {
            let item = outlineView.selectedItem
            return item as? ResourceType ?? (item as? Resource)?.type
        }
    }

    func updated(resource: Resource, oldIndex: Int?) {
        // Should be overriden by sub-classes
    }

    func updateRow(oldIndex: Int?, newIndex: Int?, parent: Any?) {
        if let oldIndex {
            if let newIndex {
                outlineView.moveItem(at: oldIndex, inParent: parent, to: newIndex, inParent: parent)
            } else {
                outlineView.removeItems(at: IndexSet([oldIndex]), inParent: parent)
            }
        } else if let newIndex {
            outlineView.insertItems(at: IndexSet([newIndex]), inParent: parent)
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }

    // MARK: - Data Source functions

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let type = item as? ResourceType ?? currentType {
            return document.directory.filteredResources(type: type)[index]
        } else {
            return document.directory.filteredTypes()[index]
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let type = item as? ResourceType ?? currentType {
            return document.directory.filteredCount(type: type)
        } else {
            return document.directory.filteredTypes().count
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is ResourceType
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        return item as? Resource
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        let selected = self.selectedResources()
        self.setSorter()
        outlineView.reloadData()
        self.select(selected)
    }

    func setSorter() {
        guard let descriptor = outlineView.sortDescriptors.first else {
            return
        }
        if descriptor == outlineView.outlineTableColumn?.sortDescriptorPrototype {
            document.directory.sorter = nil
        } else {
            document.directory.sorter = descriptor.compare
        }
    }
}

extension NSOutlineView {
    var selectedItem: Any? {
        self.item(atRow: self.selectedRow)
    }
    var selectedItems: [Any] {
        self.selectedRowIndexes.map {
            self.item(atRow: $0)!
        }
    }
}

extension NSSortDescriptor {
    /// Returns true if the two objects are in ascending order.
    func compare(_ a: Any, _ b: Any) -> Bool {
        return self.compare(a, to: b) == .orderedAscending
    }
}
