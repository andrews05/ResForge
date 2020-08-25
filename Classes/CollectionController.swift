import Cocoa
import RKSupport

class CollectionController: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, ResourcesView {
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var document: ResourceDocument!
    private var currentType: String? = nil
    
    func reload(type: String?) {
        currentType = type
        collectionView.reloadData()
    }
    
    func select(_ resources: [Resource]) {
        var paths: Set<IndexPath> = Set()
        for resource in resources where resource.type == currentType {
            let i = document.directory.resourcesByType[currentType!]!.firstIndex(of: resource)!
            paths.insert([0, i])
        }
        collectionView.selectionIndexPaths = paths
        collectionView.scrollToItems(at: paths, scrollPosition: .top)
    }
    
    func selectionCount() -> Int {
        return collectionView.selectionIndexes.count
    }
    
    func selectedResources(deep: Bool = false) -> [Resource] {
        return self.resources(for: collectionView.selectionIndexPaths)
    }
    
    func selectedType() -> String? {
        return currentType == "" ? nil : currentType
    }
    
    private func resources(for indexes: Set<IndexPath>) -> [Resource] {
        return indexes.map {
            document.directory.resourcesByType[currentType!]![$0.last!]
        }
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
        return document.directory.resourcesByType[currentType!]![index]
    }
    
    // Don't hide original items when dragging
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexes: Set<IndexPath>) {
        for i in indexes {
            collectionView.item(at: i)!.view.isHidden = false
        }
    }
    
    // MARK: - DataSource functions
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return document.directory.resourcesByType[currentType!]!.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let resource = document.directory.resourcesByType[currentType!]![indexPath.last!]
        let view = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "ResourceItem"), for: indexPath)
        view.imageView?.image = PluginManager.editor(for: resource.type)?.image?(for: resource)
        view.textField?.stringValue = resource.name
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
}
