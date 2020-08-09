import Cocoa

extension NSOutlineView {
    var selectedItem: Any? {
        if self.numberOfSelectedRows == 1 {
            return self.item(atRow: self.selectedRow)
        } else {
            return nil
        }
    }
    
    var selectedItems: [Any] {
        return self.selectedRowIndexes.map {
            self.item(atRow: $0)!
        }
    }
}
