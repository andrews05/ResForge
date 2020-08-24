import Cocoa
import RKSupport

class CollectionController: NSObject, NSCollectionViewDelegate, NSCollectionViewDataSource, ResourcesView {
    @IBOutlet var collectionView: NSCollectionView!
    @IBOutlet var document: ResourceDocument!
    private var currentType: String? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.registerForDraggedTypes([.RKResource])
    }
    
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
    
    func changed(resource: Resource, newIndex: Int) {
        
    }
    
    // MARK: - Delegate functions
    
    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }
    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        NotificationCenter.default.post(name: .DocumentSelectionDidChange, object: document)
    }
    
//    func collectionView(_ collectionView: NSCollectionView, pasteboardWriterForItemAt index: Int) -> NSPasteboardWriting? {
//        return document.directory.resourcesByType[currentType!]![index]
//    }
    
    func collectionView(_ collectionView: NSCollectionView, writeItemsAt indexes: Set<IndexPath>, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.declareTypes([.RKResource], owner: nil)
        let data = NSKeyedArchiver.archivedData(withRootObject: self.resources(for: indexes))
        pasteboard.setData(data, forType: .RKResource)
        return true
    }
    
    // Don't hide original items when dragging
    func collectionView(_ collectionView: NSCollectionView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint, forItemsAt indexes: Set<IndexPath>) {
        for i in indexes {
            collectionView.item(at: i)!.view.isHidden = false
        }
    }
    
    func collectionView(_ collectionView: NSCollectionView, validateDrop draggingInfo: NSDraggingInfo, proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>, dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        if draggingInfo.draggingSource as AnyObject === collectionView {
            return []
        }
        proposedDropOperation.pointee = .on
        return .copy
    }
    
    func collectionView(_ collectionView: NSCollectionView, acceptDrop draggingInfo: NSDraggingInfo, indexPath: IndexPath, dropOperation: NSCollectionView.DropOperation) -> Bool {
        if let data = draggingInfo.draggingPasteboard.data(forType: .RKResource),
            let resources = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Resource] {
            document.add(resources: resources)
            return true
        }
        return false
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
