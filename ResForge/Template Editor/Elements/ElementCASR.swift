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
class ElementCASR: CasedElement, ComboBoxLink {
    @objc var value: Int {
        get {
            parentElement.displayValue
        }
        set {
            parentElement.displayValue = newValue
        }
    }
    private(set) var min = 0
    private(set) var max = 0
    private var offset = 0
    private var invert = false
    private var resType: String?
    weak var parentElement: RangedElement!
    
    override var description: String {
        self.displayLabel
    }
    
    convenience init(value: Int) {
        self.init(type: "CASR", label: "")
        min = value
        max = value
        displayLabel = String(value)
    }
    
    override func configure() throws {
        throw TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a supported element.", comment: ""))
    }
    
    override func configure(view: NSView) {
        if min == max {
            self.width = 0
        } else if let resType = resType {
            // If a resType has been given this will become a combo box for resource selection
            self.loadCases(resType)
            self.configureComboLink(view: view)
        } else {
            self.configureTextField(view: view)
        }
    }
    
    override var formatter: Formatter {
        sharedFormatter("\(min):\(max)") {
            let formatter = NumberFormatter()
            formatter.minimum = min as NSNumber
            formatter.maximum = max as NSNumber
            formatter.allowsFloats = false
            formatter.nilSymbol = "\0"
            return formatter
        }
    }
    
    // MARK: -
    
    func configure(for element: RangedElement) throws {
        self.parentElement = element
        self.parentList = element.parentList // Required to trigger itemValueUpdated
        self.width = element.width
        min = (element.formatter as? NumberFormatter)?.minimum as? Int ?? Int.min
        max = (element.formatter as? NumberFormatter)?.maximum as? Int ?? Int.max
        let range = min...max
        
        // Determine parameters from label
        var hasMin = false
        var hasMax = false
        if let metaValue = metaValue {
            let scanner = Scanner(string: metaValue)
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
    }
    
    private func loadCases(_ resType: String) {
        guard cases.isEmpty else {
            return
        }
        self.width = parentElement.casrs.count > 1 ? 180 : 240
        let resources = self.parentList.controller.resources(ofType: resType)
        for resource in resources where min...max ~= resource.id {
            let caseEl = ElementCASE(value: resource.id,
                                     displayLabel: "\(resource.id) = \(resource.name)",
                                     displayValue: "\(resource.name) = \(resource.id)")
            self.cases[resource.id] = caseEl
        }
    }
    
    func openResource(_ sender: Any) {
        if let resType = resType {
            self.parentList.controller.openOrCreateResource(typeCode: resType, id: value)
        }
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
