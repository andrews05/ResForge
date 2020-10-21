import Cocoa

// Abstract Element subclass that handles CASR elements
class RangeableElement: CaseableElement {
    @objc dynamic var displayValue = 0
    @objc private(set) var casrs: [ElementCASR]!
    @objc private var currentCase: ElementCASR!
    var popupWidth: CGFloat = 240
    
    override func configure() throws {
        // Read CASR elements
        while let casr = self.parentList.pop("CASR") as? ElementCASR {
            if casrs == nil {
                casrs = []
            }
            try casr.configure(for: self)
            casrs.append(casr)
            if casr.min != casr.max {
                popupWidth = 180 // Shrink pop-up menu if any CASR needs a field
            }
        }
        if casrs == nil {
            try super.configure()
        }
    }
    
    override func configure(view: NSView) {
        if casrs == nil {
            super.configure(view: view)
            return
        }
        
        if currentCase == nil {
            self.loadValue()
        }
        // Only show the select menu if there are multiple options
        if casrs.count > 1 {
            let orig = view.frame
            var frame = view.frame
            frame.size.width = popupWidth-1
            frame.size.height = 23
            frame.origin.y = -1
            let select = NSPopUpButton(frame: frame)
            select.target = self
            select.action = #selector(caseChanged(_:))
            select.bind(.content, to: self, withKeyPath: "casrs", options: nil)
            select.bind(.selectedObject, to: self, withKeyPath: "currentCase", options: nil)
            view.addSubview(select)
            frame = view.frame
            frame.origin.x += popupWidth
            view.frame = frame
            currentCase.configure(view: view)
            self.width = popupWidth + currentCase.width
            view.frame = orig
        } else {
            currentCase.configure(view: view)
            self.width = currentCase.width
        }
    }
    
    private func loadValue() {
        let value = self.value(forKey: "value") as! Int
        currentCase = casrs.first(where: { $0.matches(value: value) })
        if let currentCase = currentCase {
            displayValue = currentCase.normalise(value)
        } else {
            // Force value to min of first case
            currentCase = casrs[0]
            displayValue = currentCase.min
            self.setValue(currentCase.deNormalise(displayValue), forKey: "value")
        }
        self.bind(NSBindingName("value"), to: self, withKeyPath: "displayValue", options: [.valueTransformer: self])
    }
    
    @IBAction func caseChanged(_ sender: NSPopUpButton) {
        if displayValue < currentCase.min {
            displayValue = currentCase.min
        } else if displayValue > currentCase.max {
            displayValue = currentCase.max
        } else {
            displayValue = +displayValue // Still need to trigger the transformer
        }
        let outline = self.parentList.controller.dataList!
        // Item isn't necessarily self
        // FIXME: This breaks the key view loop for the row, but reloading entire data is too inefficient.
        outline.reloadItem(outline.item(atRow: outline.row(for: sender)))
        self.parentList.controller.itemValueUpdated(sender)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return casrs == nil ? super.transformedValue(value) : currentCase.deNormalise(value as! Int)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return casrs == nil ? super.reverseTransformedValue(value) : currentCase.normalise(value as! Int)
    }
}
