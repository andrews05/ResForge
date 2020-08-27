import Cocoa
import RKSupport

class CollectionController: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, ResourcesView {
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var document: ResourceDocument!
    private var currentType: String!
    
    func reload(type: String?) {
        currentType = type!
        collectionView.reloadData()
    }
    
    func select(_ resources: [Resource]) {
        var paths: Set<IndexPath> = Set()
        for resource in resources where resource.type == currentType {
            let i = document.directory.resourcesByType[currentType]!.firstIndex(of: resource)!
            paths.insert([0, i])
        }
        collectionView.selectionIndexPaths = paths
        collectionView.scrollToItems(at: paths, scrollPosition: .top)
    }
    
    func selectionCount() -> Int {
        return collectionView.selectionIndexes.count
    }
    
    func selectedResources(deep: Bool = false) -> [Resource] {
        return collectionView.selectionIndexPaths.map {
            document.directory.resourcesByType[currentType]![$0.last!]
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
        collectionView.animator().moveItem(at: old, to: new)
        collectionView.animator().reloadItems(at: [new])
        if selected {
            collectionView.animator().selectItems(at: [new], scrollPosition: [])
        }
    }
    
    // MARK: - Delegate functions
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }
    
    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt index: Int) -> NSPasteboardWriting? {
        return document.directory.resourcesByType[currentType]![index]
    }
    
    // Don't hide original items when dragging
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexes: Set<IndexPath>) {
        for i in indexes {
            collectionView.item(at: i)?.view.isHidden = false
        }
    }
    
    // MARK: - DataSource functions
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return document.directory.resourcesByType[currentType]!.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let resource = document.directory.resourcesByType[currentType]![indexPath.last!]
        let view = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ResourceItem"), for: indexPath) as! ResourceItem
        view.imageView?.image = resource.preview()
        view.textField?.stringValue = String(resource.id)
        view.nameField.stringValue = resource.name
        view.nameField.isHidden = resource.name.count == 0
        return view
    }
}

class ResourceCollection: NSCollectionView {
    // The collection view seems to absorb delete key events - override to pass this event on
    override func keyDown(with event: NSEvent) {
        if event.specialKey == .delete {
            self.nextResponder?.keyDown(with: event)
        } else {
            super.keyDown(with: event)
        }
    }
    
    // Detect clicks only the image or text
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view is NSImageView || view is NSTextField ? view : self
    }
}

class ResourceItem: NSCollectionViewItem {
    @IBOutlet var imageBox: NSBox!
    @IBOutlet var textBox: NSBox!
    @IBOutlet var nameField: NSTextField!
    
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
}
