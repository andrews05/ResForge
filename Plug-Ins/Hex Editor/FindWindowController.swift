import Cocoa

class FindWindowController: NSWindowController, NSTextFieldDelegate {
    @IBOutlet var findText: NSTextField!
    @IBOutlet var replaceText: NSTextField!
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
    
    func controlTextDidChange(_ obj: Notification) {
        self.updateFieldData(obj.object as! NSTextField)
    }
    
    @IBAction func toggleType(_ sender: Any) {
        self.updateFieldData(findText)
        self.updateFieldData(replaceText)
    }

    @IBAction func hide(_ sender: Any) {
        self.window?.orderOut(sender)
    }

    @IBAction func findNext(_ sender: Any) {
        let controller = (sender as! NSButton).window!.sheetParent!.windowController as! HexWindowController;
        findIn(controller.textView.controller)
    }

    @IBAction func replaceAll(_ sender: Any) {
        self.hide(sender)
        //NSLog( @"Replacing all \"%@\" with \"%@\"", findText.stringValue, replaceText.stringValue );
    }
    
    private func updateFieldData(_ field: NSTextField) {
        let asHex = findType.selectedRow == 1
        var data: Data!
        if (asHex) {
            let nonHexChars = NSCharacterSet(charactersIn: "0123456789ABCDEFabcdef").inverted;
            var hexString = field.stringValue.components(separatedBy: nonHexChars).joined()
            field.stringValue = hexString;
            if hexString.count % 2 == 1 {
                hexString = "0" + hexString
            }
            data = hexString.data(using: .hexadecimal)
        } else {
            data = field.stringValue.data(using: String.Encoding.macOSRoman)
        }
        var byteArray: HFByteArray? = nil;
        if data.count > 0 {
            byteArray = HFBTreeByteArray()
            byteArray!.insertByteSlice(HFSharedMemoryByteSlice(unsharedData: data), in:HFRangeMake(0,0))
        }
        if field == findText {
            findBytes = byteArray
        } else {
            replaceBytes = byteArray
        }
    }

    func showSheet(window: NSWindow) {
        self.hide(window)
        window.beginSheet(self.window!, completionHandler: nil);
    }
    
    func findIn(_ controller: HFController, forwards: Bool = true) {
        guard let findBytes = findBytes else {
            NSSound.beep()
            return
        }
        
        let startRange = HFRangeMake(0, controller.minimumSelectionLocation())
        let endRange = HFRangeMake(controller.maximumSelectionLocation(), controller.contentsLength()-controller.maximumSelectionLocation())
        let firstRange = forwards ? endRange : startRange
        let secondRange = forwards ? startRange : endRange
        
        var idx = UInt64.max
        if self.ignoreCase.state == .on && findType.selectedRow == 0 {
            // Case-insensitive requires converting the data to a string
            let options: NSString.CompareOptions = forwards ? .caseInsensitive : [.caseInsensitive, .backwards]
            var text = String(data: controller.data(for: firstRange), encoding: .macOSRoman)!
            var index = text.range(of: findText.stringValue, options: options)?.lowerBound
            if let index = index {
                idx = firstRange.location + UInt64(text.distance(from: text.startIndex, to: index))
            } else if self.wrapAround.state == .on {
                text = String(data: controller.data(for: secondRange), encoding: .macOSRoman)!
                index = text.range(of: findText.stringValue, options: options)?.lowerBound
                if let index = index {
                    idx = secondRange.location + UInt64(text.distance(from: text.startIndex, to: index))
                }
            }
        } else {
            idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: firstRange, searchingForwards: forwards, trackingProgress: nil)
            if idx == UInt64.max && self.wrapAround.state == .on {
                idx = controller.byteArray.indexOfBytesEqual(to: findBytes, in: secondRange, searchingForwards: forwards, trackingProgress: nil)
            }
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
            findText.stringValue = data.hexadecimal
        } else {
            findText.stringValue = String(data: data, encoding: .macOSRoman)!
        }
        findBytes = controller.byteArrayForSelectedContentsRanges()
    }
}
