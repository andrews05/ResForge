import Cocoa

class OpenPanelDelegate: NSDocumentController, NSOpenSavePanelDelegate {
    @IBOutlet var accessoryView: NSView!
    @IBOutlet var forkSelect: NSPopUpButton!
    @objc private var forkIndex = 0
    // Flag indicating when a file is opened via the open panel so the document can use our selected fork
    private var useSelectedFork = false
    private let formatter = ByteCountFormatter()
    private static let forks = [nil, FileFork.data, FileFork.rsrc]
    
    func getSelectedFork() -> FileFork? {
        if !useSelectedFork {
            return nil
        }
        // The selected fork is being read, make sure we clear the flag for next time
        useSelectedFork = false
        return Self.forks[forkIndex]
    }
    
    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        openPanel.delegate = self
        openPanel.accessoryView = accessoryView
        openPanel.treatsFilePackagesAsDirectories = true
        openPanel.isAccessoryViewDisclosed = forkIndex != 0
        forkSelect.item(at: 1)?.title = FileFork.data.name
        forkSelect.item(at: 2)?.title = FileFork.rsrc.name
        
        let response = super.runModalOpenPanel(openPanel, forTypes: types)
        if response == NSApplication.ModalResponse.OK.rawValue {
            // We're opening a file from the open panel, set the flag
            useSelectedFork = true
        }
        return response
    }
    
    func panelSelectionDidChange(_ sender: Any?) {
        guard let url = (sender as! NSOpenPanel).url else {
            forkSelect.item(at: 1)?.title = FileFork.data.name
            forkSelect.item(at: 2)?.title = FileFork.rsrc.name
            return
        }
        // Show the fork sizes in the menu
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileSizeKey])
        } catch {
            return
        }
        let dataSize = values.fileSize!
        let rsrcSize = values.totalFileSize! - values.fileSize!
        let dataString = dataSize > 0 ? formatter.string(fromByteCount: Int64(dataSize)) : "empty"
        let rsrcString = rsrcSize > 0 ? formatter.string(fromByteCount: Int64(rsrcSize)) : "empty"
        forkSelect.item(at: 1)?.title = "\(FileFork.data.name) (\(dataString))"
        forkSelect.item(at: 2)?.title = "\(FileFork.rsrc.name) (\(rsrcString))"
    }
}
