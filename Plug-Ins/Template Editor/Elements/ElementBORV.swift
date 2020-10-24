import Cocoa
import RKSupport

/*
 * BORV is a Rezilla creation which is an OR combination of named (CASE) values
 * In Rezilla it is displayed as a multiple select popup menu
 * In ResKnife we display it as a list of checkboxes (because we don't have enough checkbox types already!)
 * The main difference from BBITs is it allows a custom ordering of the bits (it also gives a slightly more compact display)
 */
class ElementBORV<T: FixedWidthInteger & UnsignedInteger>: ElementHBYT<T> {
    private var values: [T] = []
    
    override func configure() throws {
        // Read hex values from the CASEs
        self.cases = []
        while let caseEl = self.parentList.pop("CASE") as? ElementCASE {
            try caseEl.configure(for: self)
            self.cases.append(caseEl)
            // Store the value in our list while setting the element to 0, which will be used for the checkbox state
            values.append(caseEl.value as! T)
            caseEl.value = 0
        }
        if self.cases.isEmpty {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No ‘CASE’ elements found.", comment: ""))
        }
        self.rowHeight = Double(self.cases.count * 20) + 2
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.size.height = 20
        frame.origin.y = CGFloat(self.rowHeight) - 1
        for caseEl in self.cases {
            frame.origin.y -= 20
            let checkbox = ElementBOOL.createCheckbox(with: frame, for: caseEl)
            checkbox.title = caseEl.displayLabel
            view.addSubview(checkbox)
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        let completeValue: T = try reader.read()
        for i in self.cases.indices {
            let caseEl = self.cases[i]
            let value = self.values[i]
            caseEl.value = (completeValue & value) == value ? 1 : 0
        }
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        var completeValue: T = 0
        for i in self.cases.indices {
            if self.cases[i].value as! Int != 0 {
                completeValue |= self.values[i]
            }
        }
        writer.write(completeValue)
    }
}
