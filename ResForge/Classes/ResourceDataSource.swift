import AppKit
import RFSupport

class ResourceDataSource: NSObject {
    @IBOutlet var splitView: NSSplitView!
    @IBOutlet var typeList: NSOutlineView!
    @IBOutlet var stackView: NSStackView!
    @IBOutlet var outlineController: StandardController!
    @IBOutlet var collectionController: CollectionController!
    lazy var bulkController = BulkController(document: document)
    @IBOutlet var attributesHolder: NSView!
    @IBOutlet var attributesDisplay: NSTextField!
    @IBOutlet weak var document: ResourceDocument!
    private(set) var resourcesView: ResourcesView!
    var ignoreChanges = false

    var isBulkMode: Bool {
        resourcesView is BulkController
    }
    private(set) var useTypeList = false {
        didSet {
            let width: CGFloat = if !useTypeList {
                0
            } else if #available(macOS 11, *) {
                // The type list has additional padding on macOS 11 and shows type icons
                140
            } else {
                100
            }
            splitView.setPosition(width, ofDividerAt: 0)
            self.reload(selecting: self.selectedResources())
        }
    }
    private(set) var currentType: ResourceType? {
        didSet {
            attributesHolder.isHidden = currentType?.attributes.isEmpty ?? true
            attributesDisplay.objectValue = currentType?.attributesDisplay
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        NotificationCenter.default.addObserver(self, selector: #selector(resourceTypeDidChange(_:)), name: .ResourceTypeDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resourceDidUpdate(_:)), name: .DirectoryDidUpdateResource, object: document.directory)
        useTypeList = UserDefaults.standard.bool(forKey: RFDefaults.showSidebar)
        typeList.registerForDraggedTypes([.RFResource])
    }

    @objc func resourceTypeDidChange(_ notification: Notification) {
        guard
            !ignoreChanges,
            let document = document,
            let resource = notification.object as? Resource,
            resource.document === document
        else {
            return
        }
        self.reload(selecting: [resource])
    }

    @objc func resourceDidUpdate(_ notification: Notification) {
        guard
            !ignoreChanges,
            let resource = notification.userInfo?["resource"] as? Resource,
            !useTypeList || resource.type == currentType
        else {
            return
        }
        let oldIndex = notification.userInfo?["oldIndex"] as? Int
        resourcesView.updated(resource: resource, oldIndex: oldIndex)
    }

    @IBAction func filter(_ sender: Any) {
        if let field = sender as? NSSearchField {
            self.updateFilter(field.stringValue)
        }
    }

    /// Reload the resources view, attempting to preserve the current selection.
    private func updateFilter(_ filter: String? = nil) {
        let selection = self.selectedResources()
        if let filter {
            document.directory.filter = filter
        }
        resourcesView.reload()
        resourcesView.select(selection)
    }

    func setView(_ rView: ResourcesView? = nil, retainSelection: Bool = false) {
        let selected = retainSelection ? self.selectedResources() : []
        let rView = rView ?? self.defaultView()
        do {
            let view = try rView.prepareView(type: currentType)
            rView.reload()
            if rView !== resourcesView {
                resourcesView = rView
                stackView.removeView(stackView.views.last!)
                stackView.addView(view, in: .bottom)
                view.window?.initialFirstResponder = view
                view.window?.makeFirstResponder(view)
            }
            if retainSelection {
                resourcesView.select(selected)
            } else {
                (view as? NSScrollView)?.documentView?.scrollToVisible(.zero)
            }
        } catch let error {
            document.presentError(error)
        }
    }

    private func defaultView() -> ResourcesView {
        if let currentType, PluginRegistry.previewProviders[currentType.code] != nil {
            return collectionController
        }
        return outlineController
    }

    // MARK: - Resource management

    /// Reload the data source after performing a given operation. The resources returned from the operation will be selected.
    ///
    /// This function is important for managing undo operations when adding/removing resources. It creates an undo group and ensures that the data source is always reloaded after the operation is peformed, even when undoing/redoing.
    func reload(actionName: String, after operation: () -> [Resource]) {
        document.undoManager?.beginUndoGrouping()
        self.willReload(actionName: actionName)
        self.reload(selecting: operation(), actionName: actionName)
        document.undoManager?.endUndoGrouping()
    }

    /// Register intent to reload the data source before performing changes.
    private func willReload(_ resources: [Resource] = [], actionName: String) {
        ignoreChanges = true
        document.undoManager?.registerUndo(withTarget: self) {
            $0.reload(selecting: resources, actionName: actionName)
        }
        document.undoManager?.setActionName(actionName)
    }

    /// Reload the view and select the given resources.
    func reload(selecting resources: [Resource] = [], actionName: String? = nil) {
        typeList.reloadData()
        if useTypeList, !document.directory.allTypes.isEmpty {
            // Select the first available type if nothing else selected (-1 becomes 1)
            let i = abs(typeList.row(forItem: resources.first?.type ?? currentType))
            typeList.selectRowIndexes([i], byExtendingSelection: false)
        } else {
            currentType = nil
            self.setView()
        }
        resourcesView.select(resources)
        if let actionName {
            ignoreChanges = false
            document.undoManager?.registerUndo(withTarget: self) {
                $0.willReload(resources, actionName: actionName)
            }
            document.undoManager?.setActionName(actionName)
        }
    }

    /// Return the number of selected items.
    func selectionCount() -> Int {
        return resourcesView.selectionCount()
    }

    /// Return a flat list of all resources in the current selection, optionally including resources within selected type lists.
    func selectedResources(deep: Bool = false) -> [Resource] {
        return resourcesView?.selectedResources(deep: deep) ?? []
    }

    /// Return the currently selected type.
    func selectedType() -> ResourceType? {
        return resourcesView.selectedType()
    }
}

// Sidebar control
extension ResourceDataSource: NSSplitViewDelegate {
    func toggleSidebar() {
        useTypeList = !useTypeList
        UserDefaults.standard.set(useTypeList, forKey: RFDefaults.showSidebar)
    }

    // Prevent dragging the divider
    func splitView(_ splitView: NSSplitView, effectiveRect proposedEffectiveRect: NSRect, forDrawnRect drawnRect: NSRect, ofDividerAt dividerIndex: Int) -> NSRect {
        return .zero
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
}

// Sidebar type list
extension ResourceDataSource: NSOutlineViewDelegate, NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let view: NSTableCellView
        if let type = item as? ResourceType {
            let count = String(document.directory.resourceMap[type]!.count)
            view = outlineView.makeView(withIdentifier: tableColumn!.identifier, owner: nil) as! NSTableCellView
            view.imageView?.image = document.editorManager.image(for: type)
            view.textField?.stringValue = type.code
            // Show a + indicator when the type has attributes
            (view.subviews[2] as? NSTextField)?.stringValue = type.attributes.isEmpty ? "" : "+"
            (view.subviews.last as? NSButton)?.title = count
        } else {
            view = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("HeaderCell"), owner: nil) as! NSTableCellView
        }
        if #unavailable(macOS 11) {
            // Remove image view and adjust padding on older macOS
            view.imageView?.removeFromSuperview()
            for constraint in view.constraints {
                if constraint.identifier == "left-padding" {
                    constraint.constant = 8
                } else if constraint.identifier == "right-padding" {
                    constraint.constant = 4
                }
            }
        }
        return view
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return document.directory.allTypes.count + 1
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if index == 0 {
            return "Types"
        } else {
            return document.directory.allTypes[index-1]
        }
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }

    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return !(item is ResourceType)
    }

    // Prevent deselection (using the allowsEmptySelection property results in undesirable selection changes)
    func outlineView(_ outlineView: NSOutlineView, selectionIndexesForProposedSelection proposedSelectionIndexes: IndexSet) -> IndexSet {
        return proposedSelectionIndexes.isEmpty || proposedSelectionIndexes == [0] ? outlineView.selectedRowIndexes : proposedSelectionIndexes
    }

    // Allow changing type by drag and drop onto a different type
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        if let type = item as? ResourceType, type != currentType
            && (info.draggingSource as? NSView)?.window === outlineView.window {
            return .move
        }
        return []
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let type = item as? ResourceType,
              var resources = info.draggingPasteboard.readObjects(forClasses: [Resource.self]) as? [Resource]
        else {
            return false
        }
        // The pasteboard objects are not the original resources, we have to look them up
        resources = resources.compactMap {
            document.directory.findResource(type: $0.type, id: $0.id)
        }
        guard !resources.isEmpty else {
            return false
        }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Are you sure you want to change the type of the selected resources?", comment: "")
        alert.informativeText = String(format: NSLocalizedString("Current type: %@\nNew type: %@", comment: ""), resources[0].type.description, type.description)
        alert.addButton(withTitle: NSLocalizedString("Change Type", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
        alert.beginSheetModal(for: document.windowForSheet!) { modalResponse in
            if modalResponse == .alertFirstButtonReturn {
                DispatchQueue.main.async {
                    self.document.changeTypes(resources: resources, type: type)
                }
            }
        }
        return true
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        let type = typeList.selectedItem as! ResourceType
        // Check if type actually changed, rather than just being reselected after a reload
        if currentType != type {
            currentType = type
            self.setView()
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        } else {
            resourcesView.reload()
        }
    }
}

// Prevent the source list from becoming first responder
class SourceList: NSOutlineView {
    override var acceptsFirstResponder: Bool { false }
}

// Pass badge click through to parent
class SourceCount: NSButton {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

// Common interface for the OutlineController and CollectionController
protocol ResourcesView: AnyObject {
    /// Prepare the view to be displayed within the scroll view.
    func prepareView(type: ResourceType?) throws -> NSView

    /// Reload the data in the view.
    func reload()

    /// Select the given resources.
    func select(_ resources: [Resource])

    /// Return the number of selected items.
    func selectionCount() -> Int

    /// Return a flat list of all resources in the current selection, optionally including resources within selected type lists.
    func selectedResources(deep: Bool) -> [Resource]

    /// Return the currently selcted type.
    func selectedType() -> ResourceType?

    /// Notify the view that a resource has been updated.
    func updated(resource: Resource, oldIndex: Int?)
}
