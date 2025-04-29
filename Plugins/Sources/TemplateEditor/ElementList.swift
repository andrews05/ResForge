import AppKit
import RFSupport

class ElementList {
    private(set) weak var parentElement: BaseElement?
    private(set) weak var controller: TemplateEditor!
    private var elements: [BaseElement] = []
    private var visibleElements: [BaseElement] = []
    private var currentIndex = 0
    private var configured = false
    var count: Int {
        return visibleElements.count
    }

    init(controller: TemplateEditor, parent: BaseElement? = nil) {
        parentElement = parent
        self.controller = controller
    }

    func copy() throws -> ElementList {
        let list = ElementList(controller: controller, parent: parentElement)
        list.elements = elements.map({ $0.copy() as BaseElement })
        try list.configure()
        return list
    }

    func configure() throws {
        guard !configured else {
            return
        }
        while currentIndex < elements.count {
            let element = elements[currentIndex]
            element.parentList = self
            if element.visible {
                visibleElements.append(element)
            }
            try element.configure()
            currentIndex += 1
        }
        configured = true
    }

    func readTemplate(_ template: Resource, filterName: String?) -> Bool {
        do {
            elements = try TemplateParser(template: template, manager: controller.manager).parse()
            // Check if we need to prepend an RNAM element.
            let includeName = controller.resource.document != nil && UserDefaults.standard.bool(forKey: TemplateEditor.resourceNameInTemplate)
            if includeName && !(elements.first is ElementRNAM) {
                elements.insert(ElementRNAM(type: "RNAM", label: "Resource Name"), at: 0)
            }
            // Configure all elements.
            try self.configure()
            // If RNAM not enabled, make sure any existing one is removed. Do this after configure to account for CASEs.
            if !includeName && elements.first is ElementRNAM {
                elements.removeFirst()
                visibleElements.removeFirst()
            }
            // If a filter is used, insert a notice - it should come after the RNAM if present.
            if let filterName {
                let filterNotice = ElementDVDR(type: "DVDR", label: "Filter Enabled: \(filterName)")
                let idx = includeName ? 1 : 0
                elements.insert(filterNotice, at: idx)
                visibleElements.insert(filterNotice, at: idx)
            }
            return true
        } catch let error {
            let element = ElementDVDR(type: "DVDR", label: "Template Error\n\(error.localizedDescription)")
            elements = [element]
            visibleElements = [element]
            return false
        }
    }

    func getData() -> Data {
        let writer = BinaryDataWriter()
        self.writeData(to: writer)
        return writer.data
    }

    // MARK: -

    func element(at index: Int) -> BaseElement {
        return visibleElements[index]
    }

    // Insert a new element before the current element during read/configure
    func insert(_ element: BaseElement) {
        elements.insert(element, at: currentIndex)
        element.parentList = self
        currentIndex += 1
        if element.visible {
            let visIndex = visibleElements.firstIndex(of: elements[currentIndex]) ?? visibleElements.endIndex
            visibleElements.insert(element, at: visIndex)
        }
    }

    // Insert a new element before/after a given element
    func insert(_ element: BaseElement, before: BaseElement) {
        elements.insert(element, at: elements.firstIndex(of: before)!)
        element.parentList = self
        if element.visible {
            visibleElements.insert(element, at: visibleElements.firstIndex(of: before)!)
        }
    }

    func insert(_ element: BaseElement, after: BaseElement) {
        elements.insert(element, at: elements.firstIndex(of: after)! + 1)
        element.parentList = self
        if element.visible {
            visibleElements.insert(element, at: visibleElements.firstIndex(of: element)! + 1)
        }
    }

    func remove(_ element: BaseElement) {
        elements.removeAll(where: { $0 == element })
        visibleElements.removeAll(where: { $0 == element })
    }

    // MARK: -

    // The following methods may be used by elements while reading their sub elements

    // Peek at an element in the list without removing it
    func peek(_ n: Int) -> BaseElement? {
        let i = currentIndex + n
        return i < elements.endIndex ? elements[i] : nil
    }

    // Pop the next element out of the list
    func pop(_ type: String? = nil) -> BaseElement? {
        let i = currentIndex + 1
        if i >= elements.endIndex {
            return nil
        }
        let element = elements[i]
        if let type, element.type != type {
            return nil
        }
        elements.remove(at: i)
        return element
    }

    // Search for an element of a given type following the current one
    func next(ofType type: String) -> BaseElement? {
        return elements[(currentIndex+1)...].first(where: { $0.type == type })
    }

    // Search for an element of a given type preceding the current one, travsersing up the hierarchy if necessary
    func previous(ofType type: String) -> BaseElement? {
        if let element = elements[0..<currentIndex].last(where: { $0.type == type }) {
            return element
        }
        return parentElement?.parentList.previous(ofType: type)
    }

    // Search for the next visible element with the given display label
    func next(withLabel label: String) -> BaseElement? {
        for el in elements[(currentIndex+1)...] where el.visible {
            if el.displayLabel == label {
                return el
            }
        }
        return nil
    }

    // Create a new ElementList by extracting all elements following the current one up until a given type
    func subList(for startElement: CollectionElement) throws -> ElementList {
        let list = ElementList(controller: controller, parent: startElement)
        var nesting = 0
        while true {
            guard let element = self.pop() else {
                throw TemplateError.unclosedElement(startElement)
            }
            if (element as? CollectionElement)?.endType == startElement.endType {
                nesting += 1
            } else if element.type == startElement.endType {
                if nesting == 0 {
                    break
                }
                nesting -= 1
            }
            list.elements.append(element)
        }
        return list
    }

    // MARK: -

    func readData(from reader: BinaryDataReader) throws {
        let bigEndian = reader.bigEndian
        currentIndex = 0
        // Don't use for loop here as the list may be modified while reading
        while currentIndex < elements.count {
            try elements[currentIndex].readData(from: reader)
            currentIndex += 1
        }
        // Always restore original endianness at the end of any sublist
        reader.bigEndian = bigEndian
    }

    func writeData(to writer: BinaryDataWriter) {
        let bigEndian = writer.bigEndian
        for element in elements {
            element.writeData(to: writer)
        }
        writer.bigEndian = bigEndian
    }
}
