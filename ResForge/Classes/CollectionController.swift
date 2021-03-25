import Cocoa
import RFSupport

class CollectionController: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, ResourcesView {
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet weak var document: ResourceDocument!
    private(set) var currentType: String?
    
    func reload(type: String?) {
        currentType = type!
        collectionView.reloadData()
    }
    
    func select(_ resources: [Resource]) {
        var paths: Set<IndexPath> = Set()
        for resource in resources where resource.type == currentType {
            if let i = document.directory.filteredResources(type: currentType!).firstIndex(of: resource) {
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
            let list = document.directory.filteredResources(type: currentType!)
            let idx = $0.last!
            return list.indices.contains(idx) ? list[idx] : nil
        }
    }
    
    func selectedType() -> String? {
        return currentType == "" ? nil : currentType
    }
    
    func updated(resource: Resource, oldIndex: Int, newIndex: Int) {
        let old: IndexPath = [0, oldIndex]
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
            collectionView.selectItems(at: [new], scrollPosition: .nearestHorizontalEdge)
        }
    }
    
    // MARK: - Delegate functions
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt index: Int) -> NSPasteboardWriting? {
        return document.directory.filteredResources(type: currentType!)[index]
    }
    
    // Don't hide original items when dragging
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexes: Set<IndexPath>) {
        for i in indexes {
            collectionView.item(at: i)?.view.isHidden = false
        }
    }
    
    // MARK: - DataSource functions
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        if let type = currentType {
            return document.directory.filteredResources(type: type).count
        } else {
            return 0
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let resource = document.directory.filteredResources(type: currentType!)[indexPath.last!]
        let view = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("ResourceItem"), for: indexPath) as! ResourceItem
        view.configure(resource)
        return view
    }
}

class ResourceCollection: NSCollectionView {
    // The collection view doesn't seem to have sensible key handling.
    // We need to handle home/end manually, as well as arrows keys when selection is empty,
    // pass on delete and pageup/dn to the next responder, then accept everything else.
    override func keyDown(with event: NSEvent) {
        if event.specialKey == .home {
            self.scroll(NSZeroPoint)
        } else if event.specialKey == .end {
            self.scroll(NSMakePoint(self.frame.width, self.frame.height))
        } else if (event.specialKey == .downArrow || event.specialKey == .rightArrow) && self.selectionIndexPaths.isEmpty {
            self.selectItems(at: [[0, 0]], scrollPosition: [.top,.left])
        } else if (event.specialKey == .upArrow || event.specialKey == .leftArrow) && self.selectionIndexPaths.isEmpty {
            self.selectItems(at: [[0, self.numberOfItems(inSection: 0)-1]], scrollPosition: [.bottom,.right])
        } else if event.specialKey == .delete || event.specialKey == .pageUp || event.specialKey == .pageDown {
            self.nextResponder?.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // The delegate selection change callbacks are insufficient - best to trigger notification ourselves.
    override func didChangeValue(forKey key: String) {
        super.didChangeValue(forKey: key)
        if key == "selectionIndexPaths", let document = (self.delegate as? CollectionController)?.document {
            NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
        }
    }
    
    // Programmatic selection for some reason isn't KVO compliant - override to fix this.
    override func selectItems(at indexPaths: Set<IndexPath>, scrollPosition: NSCollectionView.ScrollPosition) {
        self.willChangeValue(for: \.selectionIndexPaths)
        super.selectItems(at: indexPaths, scrollPosition: scrollPosition)
        self.didChangeValue(for: \.selectionIndexPaths)
    }
    
    // Detect clicks only the image or text
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view is NSImageView || view is NSTextField ? view : self
    }
    
    override func insertNewline(_ sender: Any?) {
        // Begin editing the selected item when enter is pressed
        if self.selectionIndexPaths.count == 1 {
            self.scrollToItems(at: self.selectionIndexPaths, scrollPosition: .nearestHorizontalEdge)
            let item = self.item(at: self.selectionIndexPaths.first!) as! ResourceItem
            item.beginEditing()
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        // Stop editing the selected item as soon as first responder returns to us
        if self.selectionIndexPaths.count == 1, let item = self.item(at: self.selectionIndexPaths.first!) as? ResourceItem {
            item.endEditing()
        }
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

class ResourceItem: NSCollectionViewItem, NSTextFieldDelegate {
    @IBOutlet var imageBox: NSBox!
    @IBOutlet var textBox: NSBox!
    @IBOutlet var nameField: NSTextField!
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
        self.view.addGestureRecognizer(clicker)
    }
    
    private func highlight(_ on: Bool) {
        imageBox.fillColor = on ? .secondarySelectedControlColor : .clear
        textBox.fillColor = on ? .alternateSelectedControlColor : .clear
        textField?.textColor = on ? .alternateSelectedControlTextColor : .controlTextColor
    }
    
    @objc private func doubleClick() {
        let document = self.view.window!.delegate as! ResourceDocument
        // Use hex editor if holding option key
        if NSApp.currentEvent!.modifierFlags.contains(.option) {
            document.openResourcesAsHex(self)
        } else {
            document.openResources(self)
        }
    }
    
    func configure(_ resource: Resource) {
        self.resource = resource
        imageView?.image = nil
        textField?.stringValue = String(resource.id)
        nameField.stringValue = resource.name
        self.endEditing()
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
        nameField.alignment = .center
        self.view.window?.makeFirstResponder(nameField)
    }
    
    func endEditing() {
        nameField.isHidden = resource.name.isEmpty
        nameField.isEditable = false
        nameField.alignment = .natural
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        resource.name = nameField.stringValue
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(cancelOperation(_:)):
            nameField.abortEditing()
            fallthrough
        case #selector(insertNewline(_:)), #selector(insertTab(_:)), #selector(insertBacktab(_:)):
            // Return first responder to the collection view when editing should end
            self.view.window?.makeFirstResponder(self.collectionView)
            return true
        default:
            return false
        }
    }
}
