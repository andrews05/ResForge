import Cocoa

/*
 * The CASR element is an experimental case range element
 * It allows an element's value to have different interpretations based on a range that the value falls into
 * An element with CASRs shows a popup button to select the case range, followed by a text field to enter a value within that range
 * The CASR label format looks like "Display Label=minValue,maxValue normal 'TNAM'"
 * At least one of minValue and maxValue must be provided, the remainder is optional
 * The normal, if given, will normalise the value displayed in the text field - it represents what the minValue will display as
 * If minValue is greater than maxValue, the normalised values will be inverted
 * If a TNAM is provided, the text field will be combo box allowing you to select a resource of this type within the normalised range
 * A CASR may also be just a single value like a CASE, in which case no text field will be shown for this option
 * Note that you cannot associate both CASEs and CASRs to the same element
 */
class ElementCASR: CaseableElement {
    @objc var value: Int {
        get {
            parentElement.displayValue
        }
        set {
            parentElement.displayValue = newValue
        }
    }
    private(set) var min = Int.min
    private(set) var max = Int.max
    private var offset = 0
    private var invert = false
    private var resType: String!
    private var _formatter: NumberFormatter!
    var parentElement: RangeableElement!
    
    override var description: String {
        self.displayLabel
    }
    
    override func configure() throws {
        throw TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a supported element.", comment: ""))
    }
    
    func configure(for element: RangeableElement) throws {
        self.parentElement = element
        self.parentList = element.parentList // Required to trigger itemValueUpdated
        self.width = element.width
        _formatter = element.formatter?.copy() as? NumberFormatter
        let range = (_formatter.minimum as! Int)...(_formatter.maximum as! Int)
        
        // Determine parameters from label
        let components = self.label.components(separatedBy: "=")
        var hasMin = false
        var hasMax = false
        if components.count > 1 {
            let scanner = Scanner(string: components[1])
            hasMin = scanner.scanInt(&min)
            guard !hasMin || range ~= min else {
                throw TemplateError.invalidStructure(self, NSLocalizedString("Minimum value out of range for field type.", comment: ""))
            }
            scanner.charactersToBeSkipped = nil
            if scanner.scanString(",", into: nil) {
                hasMax = scanner.scanInt(&max)
                guard !hasMax || range ~= max else {
                    throw TemplateError.invalidStructure(self, NSLocalizedString("Maximum value out of range for field type.", comment: ""))
                }
                scanner.charactersToBeSkipped = .whitespacesAndNewlines
                var normal = 0
                if scanner.scanInt(&normal) {
                    guard hasMin else {
                        throw TemplateError.invalidStructure(self, NSLocalizedString("Normal requires explicit minimum.", comment: ""))
                    }
                    // Invert if min greater than max, or if min is negative and no max was specified (i.e. from min down)
                    invert = min > max || (min < 0 && !hasMax)
                    offset = (invert ? -min : min) - normal
                    min = normal
                    if hasMax {
                        max = (invert ? -max : max) - offset
                    }
                }
                if scanner.scanString("'", into: nil) {
                    var resType: NSString?
                    scanner.scanUpTo("'", into: &resType)
                    if resType?.length == 4 && scanner.scanString("'", into: nil) {
                        self.resType = resType as String?
                    }
                }
            } else {
                // Single value
                max = min
            }
        }
        guard hasMin || hasMax else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Could not determine parameters from label.", comment: ""))
        }
        guard max >= min else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Maximum must be greater than minimum.", comment: ""))
        }
        if hasMin {
            _formatter.minimum = min as NSNumber
        }
        if hasMax {
            _formatter.maximum = max as NSNumber
        }
    }
    
    override func configure(view: NSView) {
        if min == max {
            self.width = 0
            return
        }
        if resType != nil {
            self.loadCases()
            super.configure(view: view)
            ElementRSID.configureLinkButton(comboBox: view.subviews.last as! NSComboBox, for: self)
        } else {
            super.configure(view: view)
        }
    }
    
    private func loadCases() {
        guard self.cases == nil else {
            return
        }
        // If a resType has been given this will become a combo box for resource selection
        self.width = parentElement.casrs.count > 1 ? 180 : 240
        self.cases = []
        self.caseMap = [:]
        // Find resources in all documents and sort by id
        let manager = self.parentList.controller.resource.manager!
        var resources = manager.allResources(ofType: resType, currentDocumentOnly: false)
        resources.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        for resource in resources where !resource.name.isEmpty && min...max ~= resource.id {
            if self.caseMap[resource.id] == nil {
                self.cases.append(ElementCASE(value: resource.id, displayValue: "\(resource.name) = \(resource.id)"))
                self.caseMap[resource.id] = "\(resource.id) = \(resource.name)"
            }
        }
    }
    
    @IBAction func openResource(_ sender: Any) {
        let manager = self.parentList.controller.resource.manager!
        if let resource = manager.findResource(ofType: resType, id: value, currentDocumentOnly: false) {
            manager.open(resource: resource, using: nil, template: nil)
        } else {
            manager.createResource(ofType: resType, id: value, name: "")
        }
    }
    
    override var formatter: Formatter? {
        return _formatter
    }
    
    func matches(value: Int) -> Bool {
        let value = self.normalise(value)
        return min...max ~= value
    }
    
    func normalise(_ value: Int) -> Int {
        return (invert ? -value : value) - offset
    }
    
    func deNormalise(_ value: Int) -> Int {
        let value = value + offset
        return invert ? -value : value
    }
}
