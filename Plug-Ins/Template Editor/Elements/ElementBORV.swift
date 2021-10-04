import Cocoa
import RFSupport

/*
 * BORV is a Rezilla creation which is an OR combination of named (CASE) values
 * In Rezilla it is displayed as a multiple select popup menu
 * In ResForge we display it as a list of checkboxes (because we don't have enough checkbox types already!)
 * The main difference from BBITs is it allows a custom ordering of the bits (it also gives a slightly more compact display)
 *
 * Implements BORV, WORV, LORV, QORV
 */
class ElementBORV<T: FixedWidthInteger & UnsignedInteger>: ElementHBYT<T> {
    override func configure() throws {
        self.width = 120
        _ = self.defaultValue()
        try self.readCases()
        if caseMap.isEmpty {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ elements found.", comment: ""))
        }
        for case let (value as T, caseEl) in caseMap {
            // Set the element to true/false for the checkbox state
            caseEl.value = (tValue & value) == value
        }
        self.rowHeight = Double(caseMap.count * 20) + 2
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 1
        frame.size.height = 20
        for caseEl in caseMap.values {
            let checkbox = ElementBOOL.createCheckbox(with: frame, for: caseEl)
            checkbox.title = caseEl.displayLabel
            view.addSubview(checkbox)
            frame.origin.y += 20
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        for case let (value as T, caseEl) in caseMap {
            caseEl.value = (tValue & value) == value
        }
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        tValue = 0
        for case let (value as T, caseEl) in caseMap {
            if caseEl.value as! Bool {
                tValue |= value
            }
        }
        writer.write(tValue)
    }
}
