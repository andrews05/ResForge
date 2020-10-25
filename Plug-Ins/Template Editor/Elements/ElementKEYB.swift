import RKSupport

class ElementKEYB: Element {
    var subElements: ElementList!
    
    required init(type: String, label: String, tooltip: String? = nil) {
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = false
        self.endType = "KEYE"
    }
    
    override func copy() -> Self {
        let element = (super.copy() as Element) as! Self
        element.subElements = try? subElements?.copy()
        return element
    }
    
    override func configure() throws {
        guard subElements != nil else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Not associated to a key element.", comment: ""))
        }
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        try subElements.readData(from: reader)
    }
    
    override func dataSize(_ size: inout Int) {
        subElements.dataSize(&size)
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        subElements.writeData(to: writer)
    }
    
    override var subElementCount: Int {
        return subElements.count
    }
    
    override func subElement(at index: Int) -> Element {
        return subElements.element(at: index)
    }
}
