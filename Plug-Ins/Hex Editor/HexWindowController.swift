import Cocoa
import RKSupport

class HexWindowController: NSWindowController, NSTextFieldDelegate, ResKnifePlugin {
    let resource: Resource
    @IBOutlet var textView: HFTextView!
    
    @IBOutlet var findView: NSView!
    @IBOutlet var findField: NSTextField!
    @IBOutlet var replaceField: NSTextField!
    @IBOutlet var wrapAround: NSButton!
    @IBOutlet var ignoreCase: NSButton!
    @IBOutlet var searchText: NSButton!
    @IBOutlet var searchHex: NSButton!

    override var windowNibName: String {
        return "HexWindow"
    }
    
    required init(resource: Resource) {
        self.resource = resource
        super.init(window: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.resourceDataDidChange(_:)), name: .ResourceDataDidChange, object: resource)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        self.window?.title = resource.defaultWindowTitle;
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
        textView.controller.undoManager = self.window?.undoManager
        textView.layoutRepresenter.performLayout()
        
        // Using the textView's delegate results in a reference cycle. Register for notifications instead.
        NotificationCenter.default.addObserver(self, selector: #selector(self.hexDidChangeProperties(_:)), name: NSNotification.Name.HFControllerDidChangeProperties, object: textView.controller)
    }
    
    @objc func resourceDataDidChange(_ notification: NSNotification) {
        if !self.window!.isDocumentEdited {
            textView.data = resource.data
            self.setDocumentEdited(false) // Will have been set to true by hexDidChangeProperties
        }
    }
    
    @objc func hexDidChangeProperties(_ notification: NSNotification) {
        let properties = HFControllerPropertyBits(rawValue: notification.userInfo![HFControllerChangedPropertiesKey] as! UInt)
        if (properties.contains(.contentValue)) {
            self.setDocumentEdited(true)
        }
    }
    
    @IBAction func saveResource(_ sender: Any) {
        resource.data = textView.data!
        self.setDocumentEdited(false)
    }
    
    @IBAction func revertResource(_ sender: Any) {
        textView.data = resource.data
        self.setDocumentEdited(false)
    }
    
    // MARK: - Find/Replace

    @IBAction func showFind(_ sender: Any) {
        findField.stringValue = self.sanitize(NSPasteboard(name: .findPboard).string(forType: .string)!)
        findView.isHidden = false
        self.window?.makeFirstResponder(findField)
    }

    @IBAction func findNext(_ sender: Any) {
        if !self.find(self.findBytes(), forwards: true) {
            NSSound.beep()
        }
    }

    @IBAction func findPrevious(_ sender: Any) {
        if !self.find(self.findBytes(), forwards: false) {
            NSSound.beep()
        }
    }

    @IBAction func findWithSelection(_ sender: Any) {
        let asHex = self.window!.firstResponder!.className == "HFRepresenterHexTextView"
        searchText.state = asHex ? .off : .on
        searchHex.state = asHex ? .on : .off
        let range = (textView.controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        let data = textView.controller.data(for: range)
        if asHex {
            findField.stringValue = data.hexadecimal
        } else {
            findField.stringValue = String(data: data, encoding: .macOSRoman)!
        }
        // Save the string in the find pasteboard
        let pasteboard = NSPasteboard(name: .findPboard)
        pasteboard.clearContents()
        pasteboard.setString(findField.stringValue, forType: .string)
    }
    
    @IBAction func scrollToSelection(_ sender: Any) {
        let selection = (textView.controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        textView.controller.maximizeVisibility(ofContentsRange: selection)
        textView.controller.pulseSelection()
    }
    

    @IBAction func findAction(_ sender: Any) {
        if !findView.isHidden && !self.find(self.findBytes()) {
            NSSound.beep()
        }
    }
        
    @IBAction func find(_ sender: NSSegmentedControl) {
        if !self.find(self.findBytes(), forwards: sender.selectedTag() == 1) {
            NSSound.beep()
        }
    }
        
    @IBAction func replace(_ sender: NSSegmentedControl) {
        let data = self.data(string: replaceField.stringValue)
        if sender.selectedTag() == 0 {
            // Replace and find
            self.replace(data)
            _ = self.find(self.findBytes())
        } else {
            // Replace all
            guard let findBytes = self.findBytes() else {
                NSSound.beep()
                return
            }
            // start from top
            textView.controller.selectedContentsRanges = [HFRangeWrapper.withRange(HFRangeMake(0,0))]
            while self.find(findBytes, noWrap: true) {
                self.replace(data)
            }
        }
    }
        
    @IBAction func hideFind(_ sender: Any) {
        findView.isHidden = true
    }
    
    @IBAction func toggleType(_ sender: Any) {
        ignoreCase.isEnabled = searchText.state == .on
    }
    
    // NSTextFieldDelegate
    func controlTextDidChange(_ obj: Notification) {
        let field = obj.object as! NSTextField
        field.stringValue = self.sanitize(field.stringValue)
        if field == findField {
            // Save the string in the find pasteboard
            let pasteboard = NSPasteboard(name: .findPboard)
            pasteboard.clearContents()
            pasteboard.setString(findField.stringValue, forType: .string)
        }
    }
    
    private func findBytes() -> HFByteArray? {
        if findView.isHidden {
            // Always load from find pasteboard when view is hidden
            findField.stringValue = self.sanitize(NSPasteboard(name: .findPboard).string(forType: .string)!)
        }
        return self.byteArray(data: self.data(string: findField.stringValue))
    }
    
    private func sanitize(_ string: String) -> String {
        if (searchHex.state == .on) {
            let nonHexChars = NSCharacterSet(charactersIn: "0123456789ABCDEFabcdef").inverted;
            return string.components(separatedBy: nonHexChars).joined()
        }
        return string
    }
    
    private func data(string: String) -> Data {
        if (searchHex.state == .on) {
            var hexString = string
            if hexString.count % 2 == 1 {
                hexString = "0" + hexString
            }
            return hexString.data(using: .hexadecimal)!
        } else {
            return string.data(using: .macOSRoman)!
        }
    }
    
    private func byteArray(data: Data) -> HFByteArray? {
        if data.count == 0 {
            return nil
        }
        let byteArray = HFBTreeByteArray()
        byteArray.insertByteSlice(HFSharedMemoryByteSlice(unsharedData: data), in:HFRangeMake(0,0))
        return byteArray
    }
    
    private func find(_ findBytes: HFByteArray?, forwards: Bool = true, noWrap: Bool = false) -> Bool {
        guard var findBytes = findBytes else {
            return false
        }
        
        let controller = textView.controller
        let wrap = noWrap ? false : wrapAround.state == .on
        let startRange = HFRangeMake(0, controller.minimumSelectionLocation())
        let endRange = HFRangeMake(controller.maximumSelectionLocation(), controller.contentsLength()-controller.maximumSelectionLocation())
        var range = forwards ? endRange : startRange
        
        var idx = UInt64.max
        if ignoreCase.state == .on && searchText.state == .on {
            // Case-insensitive search is difficult and inefficient - string indices don't necessarily equal byte indices
            // 1. Convert the current search range to a atring
            // 2. Perform a string search
            // 3. Create a byte array from the match
            // 4. Proceed to byte search
            let options: NSString.CompareOptions = forwards ? .caseInsensitive : [.caseInsensitive, .backwards]
            var text = String(data: controller.data(for: range), encoding: .macOSRoman)!
            var textRange = text.range(of: findField.stringValue, options: options)
            if let textRange = textRange {
                findBytes = self.byteArray(data: text[textRange].data(using: .macOSRoman)!)!
            } else if wrap {
                range = forwards ? startRange : endRange
                text = String(data: controller.data(for: range), encoding: .macOSRoman)!
                textRange = text.range(of: findField.stringValue, options: options)
                if let textRange = textRange {
                    findBytes = self.byteArray(data: text[textRange].data(using: .macOSRoman)!)!
                }
            }
            if textRange == nil {
               return false
            }
        }
        idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        if idx == UInt64.max && wrap {
            range = forwards ? startRange : endRange
            idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        }
        
        if idx == UInt64.max {
            return false
        }
        let result = HFRangeMake(idx, findBytes.length())
        controller.selectedContentsRanges = [HFRangeWrapper.withRange(result)]
        if !noWrap {
            controller.maximizeVisibility(ofContentsRange: result)
            controller.pulseSelection()
        }
        return true
    }
    
    private func replace(_ replaceData: Data) {
        if replaceData.count > 0 {
            textView.controller.insert(replaceData, replacingPreviousBytes: 0, allowUndoCoalescing: false)
        } else {
            textView.controller.deleteSelection()
        }
    }
}
