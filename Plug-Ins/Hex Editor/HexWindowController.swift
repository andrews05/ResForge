import Cocoa

class HexWindowController: NSWindowController, NSWindowDelegate, ResKnifePlugin, HFTextViewDelegate {
    let resource: ResKnifeResource
    private let _undoManager = UndoManager()
    @IBOutlet var findView: NSView!
    @IBOutlet var textView: HFTextView!

    override var windowNibName: String! {
        return "HexWindow"
    }
    
    required init(resource: ResKnifeResource) {
        self.resource = resource
        super.init(window: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.resourceDataDidChange), name: NSNotification.Name.ResourceDataDidChange, object: resource)
        self.window?.makeKeyAndOrderFront(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    
    @objc func resourceDataDidChange(notification: NSNotification) {
        if !self.window!.isDocumentEdited {
            textView.data = resource.data
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle();
        findView.isHidden = true
        
        let lineCountingRepresenter = HFLineCountingRepresenter()
        lineCountingRepresenter.lineNumberFormat = HFLineNumberFormat.hexadecimal
        let statusBarRepresenter = HFStatusBarRepresenter()
        
        textView.layoutRepresenter.addRepresenter(lineCountingRepresenter)
        textView.layoutRepresenter.addRepresenter(statusBarRepresenter)
        textView.controller.addRepresenter(lineCountingRepresenter)
        textView.controller.addRepresenter(statusBarRepresenter)
        textView.controller.font = NSFont.userFixedPitchFont(ofSize: 10.0)!
        textView.data = resource.data
        textView.delegate = self
        textView.controller.undoManager = self._undoManager
        
        textView.layoutRepresenter.performLayout();
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if self.window!.isDocumentEdited {
            let alert = NSAlert()
            alert.messageText = "Do you want to keep the changes you made to this resource?"
            alert.informativeText = "Your changes cannot be saved later if you don't keep them."
            alert.addButton(withTitle: "Keep")
            alert.addButton(withTitle: "Don't Keep")
            alert.addButton(withTitle: "Cancel")
            alert.beginSheetModal(for: self.window!) { returnCode in
                switch (returnCode) {
                case .alertFirstButtonReturn:    // keep
                    self.saveResource(self)
                    self.window!.close()
                case .alertSecondButtonReturn:    // don't keep
                    self.window!.close()
                default:
                    break
                }
            }
            return false
        }
        return true
    }
    
    func windowWillReturnUndoManager(_ sender: NSWindow) -> UndoManager? {
        return _undoManager
    }
    
    func hexTextView(_ view: HFTextView, didChangeProperties properties: HFControllerPropertyBits) {
        if (properties.contains(.contentValue)) {
            self.setDocumentEdited(true)
        }
    }
    
    
    @IBAction func saveResource(_ sender: Any) {
        resource.data = textView.data
    }
    
    @IBAction func revertResource(_ sender: Any) {
        textView.data = resource.data
        self.setDocumentEdited(false)
    }
    

    @IBAction func showFind(_ sender: Any) {
        findView.isHidden = false
        //FindWindowController.shared.showSheet(window: self.window!)
    }
        
    @IBAction func hideFind(_ sender: Any) {
        findView.isHidden = true
    }

    @IBAction func findNext(_ sender: Any) {
        _ = FindWindowController.shared.findIn(textView.controller, forwards: true)
    }

    @IBAction func findPrevious(_ sender: Any) {
        _ = FindWindowController.shared.findIn(textView.controller, forwards: false)
    }

    @IBAction func findWithSelection(_ sender: Any) {
        let asHex = self.window!.firstResponder!.className == "HFRepresenterHexTextView"
        FindWindowController.shared.setFindSelection(textView.controller, asHex: asHex)
    }
    
    @IBAction func scrollToSelection(_ sender: Any) {
        let selection = (textView.controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        textView.controller.maximizeVisibility(ofContentsRange: selection)
        textView.controller.pulseSelection()
    }
}
