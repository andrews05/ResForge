import Cocoa

// Abstract Element subclass that handles CASR elements
class RangedElement: CasedElement {
    override var subtext: String {
        get {
            if let casr = currentCase, !casr.subtext.isEmpty {
                return casr.subtext
            }
            return super.subtext
        }
        set {
            super.subtext = newValue
        }
    }
    var displayValue = 0 {
        didSet {
            if let casr = currentCase {
                self.setValue(casr.deNormalise(displayValue), forKey: "value")
            }
        }
    }
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
        } else if let value = self.defaultValue() as? Int, self.casr(for: value) == nil {
            // If the default value didn't match a case, set value to min of first case
            self.setValue(casrs[0].deNormalise(casrs[0].min), forKey: "value")
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
            frame.size.height = 24
            let select = NSPopUpButton(frame: frame)
            select.target = self
            select.action = #selector(caseChanged(_:))
            select.bind(.content, to: self, withKeyPath: "casrs")
            select.bind(.selectedObject, to: self, withKeyPath: "currentCase")
            view.addSubview(select)
            frame = view.frame
            frame.origin.x += popupWidth
            view.frame = frame
            currentCase.configure(view: view)
            select.nextKeyView = view.subviews.last
            self.width = popupWidth + currentCase.width
            view.frame = orig
        } else {
            currentCase.configure(view: view)
            self.width = currentCase.width
        }
    }

    private func loadValue() {
        let value = self.value(forKey: "value") as? Int ?? 0
        // If the data does not match a case we still want to preserve the value:
        // When multiple cases exist, create a dummy case for the menu, else force the value into the singular case.
        let casr = self.casr(for: value) ?? (casrs.count > 1 ? ElementCASR(value: value) : casrs[0])
        // Set displayValue before currentCase to avoid re-setting the base value
        displayValue = casr.normalise(value)
        currentCase = casr
    }

    private func casr(for value: Int) -> ElementCASR? {
        return casrs.first { $0.matches(value: value) }
    }

    @IBAction func caseChanged(_ sender: NSPopUpButton) {
        // Adjust the current display value to fit the new range
        if displayValue < currentCase.min {
            displayValue = currentCase.min
        } else if displayValue > currentCase.max {
            displayValue = currentCase.max
        } else {
            displayValue = +displayValue // Still need to trigger didSet
        }
        let outline = self.parentList.controller.dataList!
        // Item isn't necessarily self
        outline.reloadItem(outline.item(atRow: outline.row(for: sender)))
        self.parentList.controller.itemValueUpdated(sender)
    }
}
