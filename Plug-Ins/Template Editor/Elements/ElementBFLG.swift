import Cocoa
import RFSupport

// Implements BFLG, WFLG, LFLG
class ElementBFLG<T: FixedWidthInteger & UnsignedInteger>: CasedElement {
    var tValue: T = 0
    @objc var value: Bool {
        get { tValue != 0 }
        set { tValue = newValue ? 1 : 0 }
    }
    
    override func configure() throws {
        try Self.readCases(for: self)
    }
    
    override func configure(view: NSView) {
        Self.configure(view: view, for: self)
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
    
    // MARK: -
    
    // Bit type elements will normally display as a checkbox but can be provided with CASEs to create radios instead.
    static func readCases(for element: CasedElement) throws {
        var valid = true
        while let caseEl = element.parentList.pop("CASE") as? ElementCASE {
            switch caseEl.displayValue.lowercased() {
            case "1", "on":
                caseEl.value = true
            case "0", "off":
                caseEl.value = false
            default:
                valid = false
            }
            if !valid || element.caseMap[caseEl.value] != nil {
                valid = false
                break
            }
            element.cases.append(caseEl)
            element.caseMap[caseEl.value] = caseEl
        }
        if !valid || (!element.cases.isEmpty && element.cases.count != 2) {
            throw TemplateError.invalidStructure(element, NSLocalizedString("CASE list must contain exactly two values: 1/On and 0/Off.", comment: ""))
        }
        element.width = element.cases.isEmpty ? 120 : 240
    }
    
    static func configure(view: NSView, for element: CasedElement) {
        if element.cases.isEmpty {
            view.addSubview(Self.createCheckbox(with: view.frame, for: element))
            return
        }
        
        var frame = view.frame
        let width = element.width / 2
        frame.size.width = width - 4
        for caseEl in element.cases {
            let radio = NSButton(frame: frame)
            radio.setButtonType(.radio)
            radio.title = caseEl.displayLabel
            radio.action = #selector(TemplateWindowController.itemValueUpdated(_:))
            let options = (caseEl.value as! Bool) ? nil : [NSBindingOption.valueTransformerName: NSValueTransformerName.negateBooleanTransformerName]
            radio.bind(.value, to: element, withKeyPath: "value", options: options)
            view.addSubview(radio)
            frame.origin.x += width
        }
    }
    
    static func createCheckbox(with frame: NSRect, for element: Element) -> NSButton {
        let checkbox = NSButton(frame: frame)
        checkbox.setButtonType(.switch)
        checkbox.bezelStyle = .regularSquare
        checkbox.title = element.metaValue ?? "\0" // Null character prevents clickable frame from taking up the whole width
        checkbox.action = #selector(TemplateWindowController.itemValueUpdated(_:))
        checkbox.bind(.value, to: element, withKeyPath: "value")
        if frame.width > 20 {
            checkbox.autoresizingMask = .width
        }
        return checkbox
    }
}
