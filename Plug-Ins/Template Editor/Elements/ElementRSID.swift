import Cocoa

/*
 * RSID allows selecting a resource id of a given type
 * The parameters are specified in the label
 * Resource type is a 4-char code enclosed in single (or smart) quotes
 * Offset is a number followed by a + (a value of zero refers to this id)
 * Limit is a number immediately following the +
 * If limit is specified the list will only show resources between offset and offset+limit
 * E.g. "Extension scope info 'scop' -27136 +2" will show 'scop' resources between -27136 and -27134
 * If the resource type cannot be determined from the label, it will look for a preceding TNAM element to determine the type
 */
class ElementRSID: ElementDBYT<Int16> {
    @objc private var resType: String! {
        didSet {
            self.loadCases()
        }
    }
    private var offset: Int = 0
    private var range: ClosedRange<Int>?
    private var fixedCases: [ElementCASE]!
    private var fixedMap: [AnyHashable: String]!
    
    override func configure() throws {
        // Determine parameters from label
        let regex = try! NSRegularExpression(pattern: "(?:.*[‘'](.{4})['’])?(?:.*?(-?[0-9]+) *[+]([0-9]+)?)?", options: [])
        let result = regex.firstMatch(in: label, options: [], range: NSMakeRange(0, label.count))
        if let nsr = result?.range(at: 1), let r = Range(nsr, in: label) {
            resType = String(label[r])
        } else {
            // See if we can bind to a preceding TNAM field
            guard let tnam = self.parentList.previous(ofType: "TNAM") else {
                throw TemplateError.invalidStructure(self, "Could not determine resource type.")
            }
            self.bind(NSBindingName("resType"), to: tnam, withKeyPath: "value")
        }
        if let nsr = result?.range(at: 2), let r = Range(nsr, in: label) {
            offset = Int(label[r])!
        }
        if let nsr = result?.range(at: 3), let r = Range(nsr, in: label) {
            range = offset...(offset + Int(label[r])!)
        }
        
        try super.configure()
        self.width = 240
        fixedCases = self.cases ?? []
        fixedMap = self.caseMap ?? [:]
        self.loadCases()
    }
    
    override func configure(view: NSView) {
        super.configure(view: view)
        Self.configureLinkButton(comboBox: view.subviews.last as! NSComboBox, for: self)
    }
    
    private func loadCases() {
        guard fixedCases != nil else {
            return
        }
        self.cases = fixedCases
        self.caseMap = fixedMap
        let resources = self.parentList.controller.resources(ofType: resType)
        for resource in resources where range?.contains(resource.id) != false {
            let resID = resource.id - offset
            if self.caseMap[resID] == nil {
                let idDisplay = self.resIDDisplay(resID)
                self.cases.append(ElementCASE(value: resource.id, displayValue: "\(resource.name) = \(idDisplay)"))
                self.caseMap[resID] = "\(idDisplay) = \(resource.name)"
            }
        }
    }
    
    private func resIDDisplay(_ resID: Int) -> String {
        // If an offset is used, the value will be displayed as "value (#actual id)"
        return offset == 0 ? String(resID) : "\(resID) (#\(resID+offset))"
    }
    
    static func configureLinkButton(comboBox: NSComboBox, for element: Element) {
        // Add a link button at the end of the combo box to open the referenced resource
        var frame = comboBox.frame
        frame.origin.x += frame.size.width - 35
        frame.origin.y += 7
        frame.size.width = 12
        frame.size.height = 12
        let button = NSButton(frame: frame)
        button.isBordered = false
        button.bezelStyle = .inline
        button.image = NSImage(named: NSImage.followLinkFreestandingTemplateName)
        button.imageScaling = .scaleProportionallyDown
        button.target = element
        button.action = #selector(openResource(_:))
        comboBox.superview?.addSubview(button)
    }
    
    @IBAction func openResource(_ sender: Any) {
        let id = Int(self.tValue)+offset
        let manager = self.parentList.controller.manager
        if let resource = manager.findResource(ofType: resType, id: id, currentDocumentOnly: false) {
            manager.open(resource: resource, using: nil, template: nil)
        } else {
            manager.createResource(ofType: resType, id: id, name: "")
        }
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return self.caseMap[value as! AnyHashable] ?? self.resIDDisplay(value as! Int)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        var value = super.reverseTransformedValue(value) as? String
        if offset != 0 {
            value = value?.components(separatedBy: " (#").first
        }
        return value ?? ""
    }
}

// Allow space for a link button
extension NSComboBoxCell {
    open override func drawingRect(forBounds rect: NSRect) -> NSRect {
        var r = super.drawingRect(forBounds: rect)
        let source = (self.dataSource as? NSComboBox)?.dataSource
        if source is ElementRSID || source is ElementCASR {
            r.size.width -= 15
        }
        return r
    }
}
