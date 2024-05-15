import AppKit
import RFSupport

class ImportPanel: NSObject, NSOpenSavePanelDelegate {
    @IBOutlet var accessoryView: NSView!
    @IBOutlet var typeSelect: NSPopUpButton!
    @IBOutlet weak var document: ResourceDocument!

    func show(callback: @escaping(URL, ResourceType) -> Void) {
        let type = document.dataSource.selectedType()
        let types = document.editorManager.allResources(ofType: .BasicTemplate)
            .map(\.name).sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
        typeSelect.removeAllItems()
        typeSelect.addItems(withTitles: types)
        if !self.select(type: type?.code) {
            // Default to 'STR ' - the only standard type we currently have a TMPB for
            self.select(type: "STR ")
        }
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["csv"]
        panel.accessoryView = accessoryView
        panel.isAccessoryViewDisclosed = true
        panel.delegate = self
        panel.beginSheetModal(for: document.windowForSheet!) { modalResponse in
            if modalResponse == .OK, let url = panel.url, let typeCode = self.typeSelect.titleOfSelectedItem {
                callback(url, ResourceType(typeCode, type?.attributes ?? [:]))
            }
        }
    }

    func panelSelectionDidChange(_ sender: Any?) {
        guard let url = (sender as! NSOpenPanel).url else {
            return
        }
        self.select(type: url.deletingPathExtension().lastPathComponent)
    }

    @discardableResult private func select(type: String?) -> Bool {
        if let type, let item = typeSelect.item(withTitle: type) {
            typeSelect.select(item)
            return true
        }
        return false
    }
}
