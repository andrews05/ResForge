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
    private var values: [T] = []
    
    override func configure() throws {
        self.width = 120
        // Read hex values from the CASEs
        self.cases = []
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            try caseEl.configure(for: self)
            self.cases.append(caseEl)
            // Store the value in our list while setting the element to 0/1, which will be used for the checkbox state
            let value = caseEl.value as! T
            values.append(value)
            caseEl.value = (tValue & value) == value ? 1 : 0
        }
        if self.cases.isEmpty {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ elements found.", comment: ""))
        }
        self.rowHeight = Double(self.cases.count * 20) + 2
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 1
        frame.size.height = 20
        for caseEl in self.cases {
            let checkbox = ElementBOOL.createCheckbox(with: frame, for: caseEl)
            checkbox.title = caseEl.displayLabel
            view.addSubview(checkbox)
            frame.origin.y += 20
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
        for (i, caseEl) in self.cases.enumerated() {
            caseEl.value = (tValue & values[i]) == values[i] ? 1 : 0
        }
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        tValue = 0
        for (i, caseEl) in self.cases.enumerated() {
            if caseEl.value as! T != 0 {
                tValue |= values[i]
            }
        }
        writer.write(tValue)
    }
}
