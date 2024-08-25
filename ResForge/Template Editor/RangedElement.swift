import AppKit

protocol RangedController: CasedElement {
    var displayValue: Int { get set }
    var hasPopup: Bool { get }
    var popupWidth: Double { get set }
}

// Abstract Element subclass that handles CASR elements
class RangedElement<T: FixedWidthInteger>: CasedElement, RangedController {
    var tValue: T = 0

    override var subtext: String {
        get {
            if let currentCase, !currentCase.subtext.isEmpty {
                return currentCase.subtext
            }
            return super.subtext
        }
        set {
            super.subtext = newValue
        }
    }
    var displayValue = 0 {
        didSet {
            if let currentCase {
                tValue = T(currentCase.deNormalise(displayValue))
            }
        }
    }
    @objc private(set) var casrs: [ElementCASR]!
    @objc private var currentCase: ElementCASR!
    var hasPopup: Bool { casrs.count > 1 }
    var popupWidth: Double = 240

    override func configure() throws {
        // Read CASR elements
        while let casr = parentList.pop("CASR") as? ElementCASR {
            if casrs == nil {
                casrs = []
            }
            try casr.configure(for: self)
            casrs.append(casr)
            if casr.min != casr.max {
                popupWidth = 180 // Shrink pop-up menu if any CASR needs a field
            }
        }
        if let casrs {
            // Configure default value
            if let defaultValue = self.parseMetaValue() as? T {
                tValue = defaultValue
                if self.matchingCase() == nil {
                    throw TemplateError.invalidStructure(self, NSLocalizedString("Default value doesn't match any CASR.", comment: ""))
                }
            } else if self.matchingCase() == nil {
                // If the current value doesn't match a case, set value to min of first case
                tValue = T(casrs[0].deNormalise(casrs[0].min))
            }
        } else {
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
        if hasPopup {
            let orig = view.frame
            var frame = view.frame
            frame.origin.x -= 2
            frame.size.width = popupWidth + 1
            frame.size.height = 25
            if #unavailable(macOS 11) {
                frame.size.height -= 1
            }
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
            width = popupWidth + currentCase.width
            view.frame = orig
        } else {
            currentCase.configure(view: view)
            width = currentCase.width
        }
    }

    private func loadValue() {
        // If the data does not match a case we still want to preserve the value:
        // When multiple cases exist, create a dummy case for the menu, else force the value into the singular case.
        let casr = self.matchingCase() ?? (hasPopup ? ElementCASR(value: Int(tValue)) : casrs[0])
        // Set displayValue before currentCase to avoid re-setting the base value
        displayValue = casr.normalise(Int(tValue))
        currentCase = casr
    }

    private func matchingCase() -> ElementCASR? {
        return casrs.first { $0.matches(value: Int(tValue)) }
    }

    @IBAction func caseChanged(_ sender: NSPopUpButton) {
        // Adjust the current display value to fit the new range
        if displayValue < currentCase.min {
            displayValue = currentCase.min
        } else if displayValue > currentCase.max {
            displayValue = currentCase.max
        } else {
            displayValue = displayValue as Int // Still need to trigger didSet
        }
        let outline = parentList.controller.dataList!
        // Item isn't necessarily self
        outline.reloadItem(outline.item(atRow: outline.row(for: sender)))
        parentList.controller.itemValueUpdated(sender)
    }
}
