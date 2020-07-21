import Foundation

class OpenPanelDelegate: NSDocumentController, NSOpenSavePanelDelegate {
    @IBOutlet var accessoryView: NSView!
    @IBOutlet var forkSelect: NSPopUpButton!
    // Flag indicating when a file is opened via the open panel so the document can use our selected fork
    var readOpenPanelForFork = false
    private var forkIndex = 0
    private let formatter = ByteCountFormatter()
    private static let forks = [nil, "", "rsrc"]
    
    @objc func getSelectedFork() -> String? {
        if !readOpenPanelForFork {
            return nil
        }
        // The selected fork is being read, make sure we clear the flag for next time
        readOpenPanelForFork = false
        return Self.forks[forkIndex]
    }
    
    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        openPanel.delegate = self
        openPanel.accessoryView = accessoryView
        openPanel.treatsFilePackagesAsDirectories = true
        
        let response = super.runModalOpenPanel(openPanel, forTypes: types)
        if response == NSApplication.ModalResponse.OK.rawValue {
            // We're opening a file from the open panel, set the flag
            readOpenPanelForFork = true
        }
        return response
    }
    
    func panelSelectionDidChange(_ sender: Any?) {
        guard let url = (sender as! NSOpenPanel).url else {
            return
        }
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        } catch {
            return
        }
        let dataSize = formatter.string(fromByteCount: Int64(values.fileSize!))
        let rsrcSize = formatter.string(fromByteCount: Int64(values.totalFileSize! - values.fileSize!))
        forkSelect.removeAllItems()
        forkSelect.addItems(withTitles: [
            NSLocalizedString("Automatic", comment: ""),
            NSLocalizedString("Data Fork", comment: "").appendingFormat(" (%@)", dataSize),
            NSLocalizedString("Resource Fork", comment: "").appendingFormat(" (%@)", rsrcSize)
        ])
        if forkIndex < forkSelect.numberOfItems {
            forkSelect.selectItem(at: forkIndex)
        }
    }
    
    @IBAction func selectFork(_ sender: Any?) {
        forkIndex = forkSelect.indexOfSelectedItem
    }
}
