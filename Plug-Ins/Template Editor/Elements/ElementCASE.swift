class ElementCASE: Element {
    let value: String
 
    required init(type: String, label: String, tooltip: String = "") {
        self.value = label.components(separatedBy: "=").last!
        super.init(type: type, label: label, tooltip: tooltip)
        self.visible = false
    }
    
    override func configure() throws {
        throw TemplateError.invalidStructure("CASE element not associated to an element that supports cases.")
    }
}
