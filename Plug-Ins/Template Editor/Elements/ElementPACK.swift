import Cocoa

/*
 * The PACK element is an experimental layout control element
 * It allows packing multiple subsequent elements, identified by label, into a single row
 * This can be helpful for grouping related elements, especially if they may otherwise not be consecutive
 * The PACK label format looks like "Display Label=element1Label,element2Label"
 */
class ElementPACK: Element {
    private var subElements: [Element] = []
    
    // The row height needs to be the maximum of all child elements - calculate this dynamically in case they change (e.g. PSTR)
    override var rowHeight: Double {
        get {
            var rowHeight = super.rowHeight
            for element in subElements {
                if element.rowHeight > super.rowHeight {
                    rowHeight = element.rowHeight
                }
            }
            return rowHeight
        }
        set {
            super.rowHeight = newValue
        }
    }
    
    override func configure() throws {
        let components = self.label.components(separatedBy: "=")
        if components.count == 2 {
            for label in components[1].components(separatedBy: ",") {
                guard let element = self.parentList.next(withLabel: label) else {
                    throw TemplateError.invalidStructure(self, NSLocalizedString("A named element was not found.", comment: ""))
                }
                element.visible = false
                subElements.append(element)
            }
        }
        if subElements.isEmpty {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No elements to pack.", comment: ""))
        }
    }
    
    override func configure(view: NSView) {
        let orig = view.frame
        var frame = view.frame
        for element in subElements {
            // When packing multiple elements, attempt to reduce the width
            if subElements.count > 1, let element = element as? CaseableElement, element.cases != nil {
                if let element = element as? RangeableElement, element.popupWidth == 180 {
                    element.popupWidth = 120
                } else {
                    element.width = 180
                }
            }
            element.configure(view: view)
            frame.origin.x += element.width
            frame.size.width -= element.width
            view.frame = frame
        }
        view.frame = orig
    }
}
