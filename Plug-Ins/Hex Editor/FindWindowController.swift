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
        self.window?.orderOut(sender)
    }

    @IBAction func findNext(_ sender: Any) {
        let controller = (sender as! NSButton).window!.sheetParent!.windowController as! HexWindowController;
        self.findIn(controller.textView.controller)
    }

    @IBAction func replaceAll(_ sender: Any) {
        self.hide(sender)
        //NSLog( @"Replacing all \"%@\" with \"%@\"", findField.stringValue, replaceField.stringValue );
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

    func showSheet(window: NSWindow) {
        self.hide(window)
        window.beginSheet(self.window!, completionHandler: nil);
    }
    
    func findIn(_ controller: HFController, forwards: Bool = true) {
        guard var findBytes = findBytes else {
            NSSound.beep()
            return
        }
        
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
            } else if wrapAround.state == .on {
                range = forwards ? startRange : endRange
                text = String(data: controller.data(for: range), encoding: .macOSRoman)!
                textRange = text.range(of: findField.stringValue, options: options)
                if let textRange = textRange {
                    findBytes = self.byteArray(data: text[textRange].data(using: .macOSRoman)!)!
                }
            }
            if textRange == nil {
               NSSound.beep()
               return
            }
        }
        idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        if idx == UInt64.max && wrapAround.state == .on {
            range = forwards ? startRange : endRange
            idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: range, searchingForwards: forwards, trackingProgress: nil)
        }
        
        if idx == UInt64.max {
            NSSound.beep()
        } else {
            self.hide(self);
            let result = HFRangeMake(idx, findBytes.length());
            controller.selectedContentsRanges = [HFRangeWrapper.withRange(result)]
            controller.maximizeVisibility(ofContentsRange: result)
            controller.pulseSelection()
        }
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
