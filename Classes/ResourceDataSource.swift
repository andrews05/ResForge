import Cocoa
import RKSupport

class ResourceDataSource: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate {
    @IBOutlet var splitView: NSSplitView!
    @IBOutlet var typeList: NSTableView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var outlineController: OutlineController!
    @IBOutlet var collectionController: CollectionController!
    @IBOutlet var document: ResourceDocument!
    
    private(set) var useTypeList = UserDefaults.standard.bool(forKey: kShowSidebar)
    private var resourcesView: ResourcesView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(resourceTypeDidChange(_:)), name: .ResourceTypeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDidChange(_:)), name: .ResourceDidChange, object: nil)

        resourcesView = outlineController
        if useTypeList {
            // Attempt to select first type by default
            typeList.selectRowIndexes([1], byExtendingSelection: false)
        }
        self.updateSidebar()
    }
    
    @objc func resourceTypeDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        document.undoManager?.disableUndoRegistration()
        self.reload(selecting: [resource])
        document.undoManager?.enableUndoRegistration()
    }
    
    @objc func resourceDidChange(_ notification: Notification) {
        guard
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        let newIndex = document.directory.resourcesByType[resource.type]!.firstIndex(of: resource)!
        resourcesView.changed(resource: resource, newIndex: newIndex)
    }
    
    // MARK: - Resource management
    
    /// Reload the data source after performing a given operation. The resources returned from the operation will be selected.
    ///
    /// This function is important for managing undo operations when adding/removing resources. It creates an undo group and ensures that the data source is always reloaded after the operation is peformed, even when undoing/redoing.
    func reload(after operation: () -> [Resource]?) {
        document.undoManager?.beginUndoGrouping()
        self.willReload()
        self.reload(selecting: operation())
        document.undoManager?.endUndoGrouping()
    }
    
    /// Register intent to reload the data source before performing changes.
    private func willReload(_ resources: [Resource]? = nil) {
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.reload(selecting: resources) })
    }
    
    /// Reload the view and select the given resources.
    func reload(selecting resources: [Resource]? = nil) {
        if useTypeList {
            typeList.reloadData()
            if let type = resources?.first?.type ?? resourcesView.selectedType(),
                let i = document.directory.allTypes.firstIndex(of: type) {
                typeList.selectRowIndexes([i+1], byExtendingSelection: false)
            } else {
                resourcesView.reload(type: "")
            }
        } else {
            resourcesView.reload(type: nil)
        }
        if let resources = resources {
            resourcesView.select(resources)
        }
        document.undoManager?.registerUndo(withTarget: self, handler: { $0.willReload(resources) })
    }
    
    /// Return the number of selected items.
    func selectionCount() -> Int {
        return resourcesView.selectionCount()
    }
    
    /// Return a flat list of all resources in the current selection, optionally including resources within selected type lists.
    func selectedResources(deep: Bool = false) -> [Resource] {
        return resourcesView.selectedResources(deep: deep)
    }
    
    /// Return the currently selected type.
    func selectedType() -> String? {
        return resourcesView.selectedType()
    }

    // MARK: - Sidebar functions
    
    func toggleSidebar() {
        useTypeList = !useTypeList
        let selection = self.selectedResources()
        if useTypeList {
            typeList.reloadData()
            // Try to make sure sure a type is selected when showing the sidebar
            if let type = resourcesView.selectedType() ?? document.directory.allTypes.first,
                let i = document.directory.allTypes.firstIndex(of: type) {
                typeList.selectRowIndexes([i+1], byExtendingSelection: false)
            } else {
                resourcesView.reload(type: "")
            }
        } else {
            resourcesView = outlineController
            scrollView.documentView = outlineView
            resourcesView.reload(type: nil)
        }
        self.updateSidebar()
        resourcesView.select(selection)
        UserDefaults.standard.set(useTypeList, forKey: kShowSidebar)
    }
    
    private func updateSidebar() {
        splitView.setPosition(useTypeList ? 110 : 0, ofDividerAt: 0)
        outlineView.indentationPerLevel = useTypeList ? 0 : 1
    }
    
    // Prevent dragging the divider
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        return NSZeroRect
    }
    
    // Sidebar width should remain fixed
    func splitView(_ splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        return splitView.subviews[1] === view
    }
    
    // Allow sidebar to collapse
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return 2
    }
    func splitView(_ splitView: NSSplitView, canCollapseSubview subview: NSView) -> Bool {
        return splitView.subviews[0] === subview
    }
    
    // Hide divider when sidebar collapsed
    func splitView(_ splitView: NSSplitView, shouldHideDividerAt dividerIndex: Int) -> Bool {
        return true
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let identifier = tableColumn?.identifier {
            let type = document.directory.allTypes[row-1]
            let count = String(document.directory.resourcesByType[type]!.count)
            let view = tableView.makeView(withIdentifier: identifier, owner: nil) as! NSTableCellView
            view.textField?.stringValue = type
            (view.subviews.last as? NSButton)?.title = count
            return view
        } else {
            return tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderCell"), owner: nil) as! NSTableCellView
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return document.directory.allTypes.count + 1
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return row != 0
    }
    
    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return row == 0
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let type: String
        if typeList.selectedRow > 0 {
            type = document.directory.allTypes[typeList.selectedRow-1]
        } else {
            type = ""
        }
        if let size = PluginManager.previewSizes[type] {
            let layout = collectionView.collectionViewLayout as! NSCollectionViewFlowLayout
            layout.itemSize = NSSize(width: size+8, height: size+26)
            resourcesView = collectionController
            scrollView.documentView = collectionView
        } else {
            resourcesView = outlineController
            scrollView.documentView = outlineView
        }
        resourcesView.reload(type: type)
    }
}

// Prevent the source list from becoming first responder
class SourceList: NSTableView {
    override var acceptsFirstResponder: Bool { false }
}

// Common interface for the OutlineController and CollectionController
protocol ResourcesView {
    /// Reload the data in the view.
    func reload(type: String?)
    
    /// Select the given resources.
    func select(_ resources: [Resource])
    
    /// Return the number of selected items.
    func selectionCount() -> Int
    
    /// Return a flat list of all resources in the current selection, optionally including resources within selected type lists.
    func selectedResources(deep: Bool) -> [Resource]
    
    /// Return the currently selcted type.
    func selectedType() -> String?
    
    /// Notify the view that a resource may have moved position.
    func changed(resource: Resource, newIndex: Int)
}
