import Foundation
import RFSupport

class ElementKEYB: Element, CollectionElement {
    let endType = "KEYE"
    var subElements: ElementList!

    required init(type: String, label: String) {
        super.init(type: type, label: label)
        self.visible = false
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

    override func writeData(to writer: BinaryDataWriter) {
        subElements.writeData(to: writer)
    }

    var subElementCount: Int {
        subElements.count
    }

    func subElement(at index: Int) -> Element {
        return subElements.element(at: index)
    }
}
