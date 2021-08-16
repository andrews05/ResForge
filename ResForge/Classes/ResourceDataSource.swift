import Cocoa
import RFSupport

class ResourceDataSource: NSObject, NSTableViewDelegate, NSTableViewDataSource, NSSplitViewDelegate {
    @IBOutlet var splitView: NSSplitView!
    @IBOutlet var typeList: NSTableView!
    @IBOutlet var typeCell: NSTableCellView!
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var outlineView: NSOutlineView!
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var outlineController: OutlineController!
    @IBOutlet var collectionController: CollectionController!
    @IBOutlet weak var document: ResourceDocument!
    
    private(set) var useTypeList = UserDefaults.standard.bool(forKey: RFDefaults.showSidebar)
    private var resourcesView: ResourcesView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(resourceTypeDidChange(_:)), name: .ResourceTypeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDidUpdate(_:)), name: .DirectoryDidUpdateResource, object: document.directory)

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
        self.reload(selecting: [resource], withUndo: false)
    }
    
    @objc func resourceDidUpdate(_ notification: Notification) {
        let resource = notification.userInfo!["resource"] as! Resource
        if !useTypeList || resource.type == resourcesView.selectedType() {
            if document.directory.filter.isEmpty {
                resourcesView.updated(resource: resource, oldIndex: notification.userInfo!["oldIndex"] as! Int, newIndex: notification.userInfo!["newIndex"] as! Int)
            } else {
                // If filter is active we need to refresh it
                self.updateFilter()
            }
        }
    }
    
    @IBAction func filter(_ sender: Any) {
        if let field = sender as? NSSearchField {
            self.updateFilter(field.stringValue)
        }
    }
    
    /// Reload the resources view, attempting to preserve the current selection.
    private func updateFilter(_ filter: String? = nil) {
        let selection = self.selectedResources()
        if let filter = filter {
            document.directory.filter = filter
        }
        resourcesView.reload(type: resourcesView.currentType)
        if selection.count != 0 {
            resourcesView.select(selection)
        }
        if self.selectionCount() == 0 {
            // No selection was made, we need to post a notification anyway
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        }
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
    func reload(selecting resources: [Resource]? = nil, withUndo: Bool = true) {
        typeList.reloadData()
        if useTypeList,
            // When showing the sidebar (withUndo = false), select the first available type if nothing else selected
            let type = resources?.first?.type ?? resourcesView.selectedType() ?? (withUndo ? nil : document.directory.allTypes.first),
            let i = document.directory.allTypes.firstIndex(of: type) {
            typeList.selectRowIndexes([i+1], byExtendingSelection: false)
        } else {
            resourcesView = outlineController
            resourcesView.reload(type: useTypeList ? ResourceType("") : nil)
            scrollView.documentView = outlineView
        }
        if let resources = resources {
            resourcesView.select(resources)
        } else {
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        }
        if withUndo {
            document.undoManager?.registerUndo(withTarget: self, handler: { $0.willReload(resources) })
        }
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
    func selectedType() -> ResourceType? {
        return resourcesView.selectedType()
    }

    // MARK: - Sidebar functions
    
    func toggleSidebar() {
        useTypeList = !useTypeList
        self.reload(selecting: self.selectedResources(), withUndo: false)
        self.updateSidebar()
        UserDefaults.standard.set(useTypeList, forKey: RFDefaults.showSidebar)
    }
    
    private func updateSidebar() {
        outlineView.indentationPerLevel = useTypeList ? 0 : 4
        outlineView.tableColumns[0].width = useTypeList ? 50 : 70
        splitView.setPosition(useTypeList ? 110 : 0, ofDividerAt: 0)
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
            view.textField?.stringValue = type.code
            (view.subviews.last as? NSButton)?.title = count
            if #available(OSX 11.0, *) {
                // Remove leading/trailing spacing on macOS 11
                for constraint in view.constraints {
                    if constraint.firstAttribute == .leading || constraint.firstAttribute == .trailing {
                        constraint.constant = 0
                    }
                }
            }
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
        let type = document.directory.allTypes[typeList.selectedRow-1]
        // Check if type actually changed, rather than just being reselected after a reload
        let changed = resourcesView.currentType != type
        if changed {
            if let provider = PluginRegistry.previewProviders[type.code] {
                let size = provider.previewSize(for: type.code)
                let layout = collectionView.collectionViewLayout as! NSCollectionViewFlowLayout
                layout.itemSize = NSSize(width: size+8, height: size+40)
                resourcesView = collectionController
                scrollView.documentView = collectionView
            } else {
                resourcesView = outlineController
                scrollView.documentView = outlineView
                outlineView.scrollToBeginningOfDocument(self)
            }
        }
        resourcesView.reload(type: type)
        if changed {
            // If the view changed we should make sure it is still first responder
            scrollView.window?.makeFirstResponder(scrollView.documentView)
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        }
    }
}

// Prevent the source list from becoming first responder
class SourceList: NSTableView {
    override var acceptsFirstResponder: Bool { false }
}

// Pass badge click through to parent
class SourceCount: NSButton {
    override func mouseDown(with event: NSEvent) {
        self.superview?.mouseDown(with: event)
    }
}

// Common interface for the OutlineController and CollectionController
protocol ResourcesView {
    /// Get the currently displayed type.
    var currentType: ResourceType? { get }
    
    /// Reload the data in the view.
    func reload(type: ResourceType?)
    
    /// Select the given resources.
    func select(_ resources: [Resource])
    
    /// Return the number of selected items.
    func selectionCount() -> Int
    
    /// Return a flat list of all resources in the current selection, optionally including resources within selected type lists.
    func selectedResources(deep: Bool) -> [Resource]
    
    /// Return the currently selcted type.
    func selectedType() -> ResourceType?
    
    /// Notify the view that a resource has been updated..
    func updated(resource: Resource, oldIndex: Int, newIndex: Int)
}
