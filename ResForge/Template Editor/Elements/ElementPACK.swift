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
            return subElements.map(\.rowHeight).max() ?? super.rowHeight
        }
        set {
            super.rowHeight = newValue
        }
    }

    override func configure() throws {
        guard let metaValue, !metaValue.isEmpty else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("No elements to pack.", comment: ""))
        }
        for label in metaValue.components(separatedBy: ",") {
            guard let element = parentList.next(withLabel: label) else {
                throw TemplateError.invalidStructure(self, NSLocalizedString("A named element was not found.", comment: ""))
            }
            guard !(element is GroupElement) && !["PACK", "CASE", "CASR"].contains(element.type) else {
                let message = String(format: NSLocalizedString("Cannot pack element of type ‘%@’.", comment: ""), element.type)
                throw TemplateError.invalidStructure(self, message)
            }
            element.visible = false
            subElements.append(element)
        }
    }

    override func configure(view: NSView) {
        let orig = view.frame
        var frame = view.frame
        for element in subElements {
            // When packing multiple elements, attempt to reduce the width
            if subElements.count > 1 {
                if element.width > 180 {
                    element.width = 180
                }
                if let element = element as? RangedElement {
                    element.popupWidth = element.popupWidth > 180 ? 180 : 120
                }
            }
            let prev = view.subviews.last
            element.configure(view: view)
            prev?.nextKeyView = view.subviews.last
            frame.origin.x += element.width
            frame.size.width -= element.width
            view.frame = frame
        }
        view.frame = orig
        width = frame.origin.x
    }
}
