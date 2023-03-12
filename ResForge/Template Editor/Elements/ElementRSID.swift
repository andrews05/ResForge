import Cocoa
import OrderedCollections
import RFSupport

/*
 * RSID allows selecting a resource id of a given type
 * The parameters are specified in the label
 * Resource type is a 4-char code enclosed in single (or smart) quotes
 * Offset is a number followed by a + (a value of zero refers to this id)
 * Limit is a number immediately following the +
 * If limit is specified the list will only show resources between offset and offset+limit
 * E.g. "Extension scope info 'scop' -27136 +2" will show 'scop' resources between -27136 and -27134
 * If the resource type cannot be determined from the label, it will look for a preceding TNAM element to determine the type
 *
 * Implements RSID, LRID
 */
class ElementRSID<T: FixedWidthInteger & SignedInteger>: CasedElement, LinkingComboBoxDelegate {
    var tValue: T = 0
    @objc dynamic private var value: NSNumber {
        get { tValue as! NSNumber }
        set { tValue = newValue as! T }
    }
    @objc private var resType = "" {
        didSet {
            self.loadCases()
        }
    }
    private var offset: Int = 0
    private var range: ClosedRange<Int>?
    private var fixedMap: OrderedDictionary<AnyHashable, ElementCASE> = [:]
    var showsLink: Bool {
        return range?.contains(Int(tValue) + offset) != false
    }

    deinit {
        self.unbind(NSBindingName("resType"))
    }

    override func configure() throws {
        // Determine parameters from label
        let regex = try! NSRegularExpression(pattern: "(?:.*['‘](.{4})['’])?(?:.*?(-?[0-9]+) *[+]([0-9]+)?)?", options: [])
        let result = regex.firstMatch(in: label, options: [], range: NSRange(location: 0, length: label.count))
        if let nsr = result?.range(at: 2), let r = Range(nsr, in: label), let i = Int(label[r]) {
            offset = i
        }
        if let nsr = result?.range(at: 3), let r = Range(nsr, in: label), let i = Int(label[r]) {
            range = offset...(offset + i)
        }

        try super.configure()
        width = 240
        fixedMap = cases

        // Setting the resType will load the cases so we need to do this last
        if let nsr = result?.range(at: 1), let r = Range(nsr, in: label) {
            resType = String(label[r])
        } else {
            // See if we can bind to a preceding TNAM field
            guard let tnam = parentList.previous(ofType: "TNAM") else {
                throw TemplateError.invalidStructure(self, "Could not determine resource type.")
            }
            self.bind(NSBindingName("resType"), to: tnam, withKeyPath: "value")
        }
    }

    override func configure(view: NSView) {
        self.configureComboBox(view: view)
    }

    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }

    override var formatter: Formatter {
        return self.sharedFormatter("INT\(T.bitWidth)") { IntFormatter<T>() }
    }

    private func loadCases() {
        cases = fixedMap
        let resources = parentList.controller.resources(ofType: resType)
        for resource in resources where range?.contains(resource.id) != false {
            let resID = resource.id - offset
            let idDisplay = self.resIDDisplay(resID)
            let caseEl = ElementCASE(value: resource.id,
                                     displayLabel: "\(idDisplay) = \(resource.name)",
                                     displayValue: "\(resource.name) = \(idDisplay)")
            cases[resID] = caseEl
        }
    }

    private func resIDDisplay(_ resID: Int) -> String {
        let id = resID + offset
        if offset != 0 && range?.contains(id) != false {
            // If an offset is used, the value will be displayed as "value (#actual id)"
            return "\(resID) (#\(id))"
        }
        return String(resID)
    }

    func followLink(_ sender: Any) {
        let id = Int(tValue) + offset
        parentList.controller.openOrCreateResource(typeCode: resType, id: id) { [self] resource, isNew in
            let resID = resource.id - offset
            // If this is new resource with a valid id, reload the cases
            if isNew && range?.contains(resID) != false {
                self.loadCases()
                value = resID as NSNumber
                // Check if the value actually changed
                if resource.id != id {
                    parentList.controller.itemValueUpdated(sender)
                }
            }
        }
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return cases[value as! AnyHashable]?.displayLabel ?? self.resIDDisplay(value as! Int)
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        var value = super.reverseTransformedValue(value) as? String
        if offset != 0 {
            value = value?.components(separatedBy: " (#").first
        }
        return value ?? ""
    }
}
