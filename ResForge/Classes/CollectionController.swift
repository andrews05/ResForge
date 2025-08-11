import AppKit
import RFSupport

class CollectionController: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, ResourcesView {
    @IBOutlet var scrollView: NSScrollView!
    @IBOutlet var collectionView: ResourceCollection!
    @IBOutlet weak var document: ResourceDocument!
    private var currentType: ResourceType!
    var isActive = false {
        didSet {
            if !isActive {
                zoomEnabled = false
            }
        }
    }
    @objc dynamic var zoomEnabled = false

    func prepareView(type: ResourceType?) -> NSView {
        if let type {
            currentType = type
            collectionView.maxSize = PluginRegistry.previewProviders[type.code]!.maxThumbnailSize(for: type.code)
                ?? ResourceCollection.zoomLevels.last!
            zoomEnabled = collectionView.maxSize > ResourceCollection.zoomLevels[0]
            document.directory.sorter = nil
        }
        return scrollView
    }

    func reload() {
        collectionView.reloadData()
    }

    func select(_ resources: [Resource]) {
        var paths: Set<IndexPath> = Set()
        for resource in resources where resource.type == currentType {
            if let i = document.directory.filteredResources(type: currentType).firstIndex(of: resource) {
                paths.insert([0, i])
            }
        }
        collectionView.selectItems(at: paths, scrollPosition: .nearestHorizontalEdge)
    }

    func selectionCount() -> Int {
        return collectionView.selectionIndexes.count
    }

    func selectedResources(deep: Bool = false) -> [Resource] {
        return collectionView.selectionIndexPaths.compactMap {
            // First attempt to get the resource from the ResourceItem
            if let r = (collectionView.item(at: $0) as? ResourceItem)?.resource {
                return r
            }
            // If the ResourceItem doesn't exist (offscreen), look it up in the directory
            // Note: If the filtered list has just changed, we can't guarantee the correct selection will be returned
            let list = document.directory.filteredResources(type: currentType)
            let idx = $0.last!
            return list.indices.contains(idx) ? list[idx] : nil
        }
    }

    func selectedType() -> ResourceType? {
        return currentType
    }

    func updated(resource: Resource, oldIndex: Int?) {
        let newIndex = document.directory.filteredResources(type: resource.type).firstIndex(of: resource)
        if let oldIndex {
            let old: IndexPath = [0, oldIndex]
            if let newIndex {
                let new: IndexPath = [0, newIndex]
                // Collection view doesn't retain selection when reloading - we need to keep track of it ourselves
                let selected = collectionView.selectionIndexPaths.contains(old)
                if old == new {
                    collectionView.reloadItems(at: [new])
                } else {
                    collectionView.animator().moveItem(at: old, to: new)
                    collectionView.animator().reloadItems(at: [new])
                }
                if selected {
                    collectionView.selectItems(at: [new], scrollPosition: old == new ? [] : .nearestHorizontalEdge)
                }
            } else {
                collectionView.animator().deleteItems(at: [old])
                NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
            }
        } else if let newIndex {
            let new: IndexPath = [0, newIndex]
            collectionView.animator().insertItems(at: [new])
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        }
    }

    // MARK: - Delegate functions
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt index: Int) -> NSPasteboardWriting? {
        return document.directory.filteredResources(type: currentType)[index]
    }

    // Don't hide original items when dragging
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexes: Set<IndexPath>) {
        for i in indexes {
            collectionView.item(at: i)?.view.isHidden = false
        }
    }

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }

    // MARK: - DataSource functions

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if let currentType {
            return document.directory.filteredCount(type: currentType)
        } else {
            return 0
        }
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let resource = document.directory.filteredResources(type: currentType)[indexPath[1]]
        let view = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("ResourceItem"), for: indexPath) as! ResourceItem
        view.configure(resource)
        return view
    }
}

class ResourceCollection: NSCollectionView {
    static let zoomLevels = [64, 100, 140, 192, 256]
    private static var preferredSize = UserDefaults.standard.integer(forKey: RFDefaults.thumbnailSize) {
        didSet {
            UserDefaults.standard.set(preferredSize, forKey: RFDefaults.thumbnailSize)
        }
    }
    // Some resource types, like small icons, may prefer to limit their max size
    @objc dynamic var maxSize = 0 {
        didSet {
            currentSize = 0
        }
    }
    @objc dynamic private var currentSize = 0 {
        didSet {
            if currentSize == 0 {
                // Reset to the preferred size without changing the preferred size
                currentSize = min(maxSize, Self.preferredSize)
            } else {
                currentSize = min(maxSize, currentSize)
                Self.preferredSize = currentSize
            }
            let layout = collectionViewLayout as! NSCollectionViewFlowLayout
            layout.itemSize = NSSize(width: currentSize+8, height: currentSize+40)
        }
    }

    @IBAction private func zoomIn(_ sender: Any) {
        if currentSize < maxSize,
           let newSize = Self.zoomLevels.first(where: { $0 > currentSize }) {
            currentSize = newSize
        }
    }

    @IBAction private func zoomOut(_ sender: Any) {
        if let newSize = Self.zoomLevels.last(where: { $0 < currentSize }) {
            currentSize = newSize
        }
    }

    // The collection view doesn't seem to have sensible key handling.
    // We need to handle home/end manually, as well as arrows keys when selection is empty,
    // pass on delete and pageup/dn to the next responder, then accept everything else.
    override func keyDown(with event: NSEvent) {
        if event.specialKey == .home {
            self.scroll(.zero)
        } else if event.specialKey == .end {
            self.scroll(NSPoint(x: frame.width, y: frame.height))
        } else if (event.specialKey == .downArrow || event.specialKey == .rightArrow) && selectionIndexPaths.isEmpty {
            self.selectItems(at: [[0, 0]], scrollPosition: [.top, .left])
        } else if (event.specialKey == .upArrow || event.specialKey == .leftArrow) && selectionIndexPaths.isEmpty {
            self.selectItems(at: [[0, self.numberOfItems(inSection: 0)-1]], scrollPosition: [.bottom, .right])
        } else if event.specialKey == .delete || event.specialKey == .pageUp || event.specialKey == .pageDown {
            self.nextResponder?.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }

    // Programmatic selection for some reason doesn't notify the delegate - override to fix this.
    override func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition) {
        super.selectItems(at: indexPaths, scrollPosition: scrollPosition)
        delegate?.collectionView?(self, didSelectItemsAt: indexPaths)
    }

    // Detect clicks only the image or text
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view is NSImageView || view is NSTextField ? view : self
    }

    override func insertNewline(_ sender: Any?) {
        // Begin editing the selected item when enter is pressed
        if selectionIndexPaths.count == 1 {
            self.scrollToItems(at: selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
            let item = self.item(at: selectionIndexPaths.first!) as! ResourceItem
            item.beginEditing()
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    // Show the resource menu when right-clicking an item, selecting it if necessary
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = self.convert(event.locationInWindow, from: nil)
        if let indexPath = self.indexPathForItem(at: point) {
            if !selectionIndexPaths.contains(indexPath) {
                self.deselectAll(self)
                self.selectItems(at: [indexPath], scrollPosition: [])
            }
            return (NSApp.delegate as? ApplicationDelegate)?.resourceMenu
        }
        return nil
    }
}

class ResourceItem: NSCollectionViewItem, NSTextFieldDelegate {
    @IBOutlet var imageBox: NSBox!
    @IBOutlet var textBox: NSBox!
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var statusIcon: NSImageView!
    private(set) var resource: Resource!

    override var isSelected: Bool {
        didSet {
            self.highlight(isSelected)
        }
    }

    override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            if !isSelected || highlightState == .forDeselection {
                self.highlight(highlightState == .forSelection)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let clicker = NSClickGestureRecognizer(target: self, action: #selector(doubleClick))
        clicker.numberOfClicksRequired = 2
        clicker.delaysPrimaryMouseButtonEvents = false
        view.addGestureRecognizer(clicker)
    }

    private func highlight(_ on: Bool) {
        imageBox.fillColor = on ? .secondarySelectedControlColor : .clear
        textBox.fillColor = on ? .alternateSelectedControlColor : .clear
        textField?.textColor = on ? .alternateSelectedControlTextColor : .controlTextColor
    }

    @objc private func doubleClick() {
        if let document = view.window?.delegate as? ResourceDocument {
            document.openResources(self)
        }
    }

    func configure(_ resource: Resource) {
        self.resource = resource
        imageView?.image = nil
        textField?.stringValue = String(resource.id)
        nameField.bind(.value, to: resource, withKeyPath: "name")
        // Hide name when empty to prevent it from being a click target
        nameField.isHidden = resource.name.isEmpty
        statusIcon.image = resource.statusIcon()
        resource.preview {
            // Check the resource is still the same, in case we got reconfigured with a different resource while waiting
            if self.resource == resource {
                self.imageView?.image = $0
            }
        }
    }

    func beginEditing() {
        nameField.isHidden = false
        nameField.isEditable = true
        nameField.window?.makeFirstResponder(nameField)
    }

    func endEditing() {
        nameField.isHidden = resource.name.isEmpty
        nameField.isEditable = false
        nameField.invalidateIntrinsicContentSize()
        // Always return first responder to the collection view
        collectionView?.window?.makeFirstResponder(collectionView)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        self.endEditing()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(cancelOperation(_:)):
            control.abortEditing()
            self.endEditing()
            return true
        default:
            return false
        }
    }
}
