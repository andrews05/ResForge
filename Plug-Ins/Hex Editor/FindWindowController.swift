import Cocoa

class FindWindowController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var findField: NSTextField!
    @IBOutlet var replaceField: NSTextField!
    @IBOutlet var wrapAround: NSButton!
    @IBOutlet var ignoreCase: NSButton!
    @IBOutlet var findType: NSMatrix!
    var findBytes: HFByteArray?
    var replaceBytes: HFByteArray?
    
    static let shared: FindWindowController = {
        let shared = FindWindowController(windowNibName: "FindSheet")
        _ = shared.window
        return shared
    }()
    
    override func windowDidLoad() {
        super.windowDidLoad()
        // Set initial string from the find pasteboard
        findField.stringValue = NSPasteboard(name: .findPboard).string(forType: .string)!
        self.updateFieldData(findField)
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let field = obj.object as! NSTextField
        self.updateFieldData(field)
        if field == findField {
            // Save the string in the find pasteboard
            let pasteboard = NSPasteboard(name: .findPboard)
            pasteboard.clearContents()
            pasteboard.setString(field.stringValue, forType: .string)
        }
    }
    
    @IBAction func toggleType(_ sender: Any) {
        self.updateFieldData(findField)
        self.updateFieldData(replaceField)
    }

    @IBAction func hide(_ sender: Any) {
        self.window?.sheetParent?.endSheet(self.window!)
    }

    @IBAction func findNext(_ sender: Any) {
        let wController = (sender as! NSButton).window!.sheetParent!.windowController as! HexWindowController
        if self.findIn(wController.textView.controller) {
            self.hide(self)
        }
    }

    @IBAction func replace(_ sender: Any) {
        let wController = (sender as! NSButton).window!.sheetParent!.windowController as! HexWindowController
        let controller = wController.textView.controller
        let range = self.replaceIn(controller)
        // Find next, else select replaced text
        if !self.findIn(controller) {
            controller.selectedContentsRanges = [HFRangeWrapper.withRange(range)]
        }
    }

    @IBAction func replaceAll(_ sender: Any) {
        guard findBytes != nil else {
            NSSound.beep()
            return
        }
        let wController = (sender as! NSButton).window!.sheetParent!.windowController as! HexWindowController
        let controller = wController.textView.controller
        self.hide(sender)
        // start from top
        controller.selectedContentsRanges = [HFRangeWrapper.withRange(HFRangeMake(0, 0))]
        while self.findIn(controller, noWrap: true) {
            _ = self.replaceIn(controller)
        }
    }
    
    private func updateFieldData(_ field: NSTextField) {
        let asHex = findType.selectedRow == 1
        var data: Data!
        if (asHex) {
            let nonHexChars = NSCharacterSet(charactersIn: "0123456789ABCDEFabcdef").inverted;
            var hexString = field.stringValue.components(separatedBy: nonHexChars).joined()
            field.stringValue = hexString
            if hexString.count % 2 == 1 {
                hexString = "0" + hexString
            }
            data = hexString.data(using: .hexadecimal)
        } else {
            data = field.stringValue.data(using: String.Encoding.macOSRoman)
        }
        if field == findField {
            findBytes = self.byteArray(data: data)
        } else {
            replaceBytes = self.byteArray(data: data)
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
    
    private func replaceIn(_ controller: HFController) -> HFRange {
        let range = (controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        let replaceLength: UInt64
        if let replaceBytes = replaceBytes {
            controller.insertByteArray(replaceBytes, replacingPreviousBytes: 0, allowUndoCoalescing: false)
            replaceLength = replaceBytes.length()
        } else {
            controller.byteArray.deleteBytes(in: range)
            replaceLength = 0
        }
        return HFRangeMake(range.location, replaceLength)
    }

    func showSheet(window: NSWindow) {
        self.hide(window)
        window.beginSheet(self.window!, completionHandler: nil);
    }
    
    func findIn(_ controller: HFController, forwards: Bool = true, noWrap: Bool = false) -> Bool {
        guard var findBytes = findBytes else {
            NSSound.beep()
            return false
        }
        
        let wrap = noWrap ? false : wrapAround.state == .on
        let startRange = HFRangeMake(0, controller.minimumSelectionLocation())
        let endRange = HFRangeMake(controller.maximumSelectionLocation(), controller.contentsLength()-controller.maximumSelectionLocation())
        var range = forwards ? endRange : startRange
        
        var idx = UInt64.max
        if ignoreCase.state == .on && findType.selectedRow == 0 {
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
               NSSound.beep()
               return false
            }
        }
        idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        if idx == UInt64.max && wrap {
            range = forwards ? startRange : endRange
            idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        }
        
        if idx == UInt64.max {
            NSSound.beep()
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

    func setFindSelection(_ controller: HFController, asHex: Bool) {
        findType.cells[0].state = asHex ? .off : .on
        findType.cells[1].state = asHex ? .on : .off
        let range = (controller.selectedContentsRanges[0] as! HFRangeWrapper).hfRange()
        let data = controller.data(for: range)
        if asHex {
            findField.stringValue = data.hexadecimal
        } else {
            findField.stringValue = String(data: data, encoding: .macOSRoman)!
        }
        findBytes = controller.byteArrayForSelectedContentsRanges()
    }
}
