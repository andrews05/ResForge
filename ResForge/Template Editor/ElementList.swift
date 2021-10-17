import Cocoa
import RFSupport

class ElementList {
    private(set) weak var parentElement: Element?
    private(set) weak var controller: TemplateEditor!
    private var elements: [Element] = []
    private var visibleElements: [Element] = []
    private var currentIndex = 0
    private var configured = false
    var count: Int {
        return visibleElements.count
    }
    
    init(controller: TemplateEditor, parent: Element? = nil) {
        parentElement = parent
        self.controller = controller
    }
    
    func copy() throws -> ElementList {
        let list = ElementList(controller: controller, parent: parentElement)
        list.elements = elements.map({ $0.copy() as Element })
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
    
    func readTemplate(_ template: Resource) -> Bool {
        do {
            let parser = TemplateParser(template: template, manager: controller.manager)
            elements += try parser.parse()
            try self.configure()
            return true
        } catch let error {
            let element = ElementDVDR(type: "DVDR", label: "Template Error\n\(error.localizedDescription)")
            elements = [element]
            visibleElements = [element]
            return false
        }
    }
    
    func getResourceData() -> Data {
        let writer = BinaryDataWriter()
        self.writeData(to: writer)
        return writer.data
    }
    
    // MARK: -
    
    func element(at index: Int) -> Element {
        return visibleElements[index]
    }

    // Insert a new element before the current element during read/configure
    func insert(_ element: Element) {
        elements.insert(element, at: currentIndex)
        element.parentList = self
        // If the element list was previously empty then we haven't started configure yet
        if elements.count > 1 {
            currentIndex += 1
            if element.visible {
                let visIndex = visibleElements.firstIndex(of: elements[currentIndex]) ?? visibleElements.endIndex
                visibleElements.insert(element, at: visIndex)
            }
        }
    }
    
    // Insert a new element before/after a given element
    func insert(_ element: Element, before: Element) {
        elements.insert(element, at: elements.firstIndex(of: before)!)
        element.parentList = self
        if element.visible {
            visibleElements.insert(element, at: visibleElements.firstIndex(of: before)!)
        }
    }
    
    func insert(_ element: Element, after: Element) {
        elements.insert(element, at: elements.firstIndex(of: after)! + 1)
        element.parentList = self
        if element.visible {
            visibleElements.insert(element, at: visibleElements.firstIndex(of: element)! + 1)
        }
    }
    
    func remove(_ element: Element) {
        elements.removeAll(where: { $0 == element })
        visibleElements.removeAll(where: { $0 == element })
    }
    
    // MARK: -
    
    // The following methods may be used by elements while reading their sub elements
    
    // Peek at an element in the list without removing it
    func peek(_ n: Int) -> Element? {
        let i = currentIndex + n
        return i < elements.endIndex ? elements[i] : nil
    }
    
    // Pop the next element out of the list
    func pop(_ type: String? = nil) -> Element? {
        let i = currentIndex + 1
        if i >= elements.endIndex {
            return nil
        }
        let element = elements[i]
        if let type = type, element.type != type {
            return nil
        }
        elements.remove(at: i)
        return element
    }
    
    // Search for an element of a given type following the current one
    func next(ofType type: String) -> Element? {
        return elements[(currentIndex+1)...].first(where: { $0.type == type })
    }
    
    // Search for an element of a given type preceding the current one, travsersing up the hierarchy if necessary
    func previous(ofType type: String) -> Element? {
        if let element = elements[0..<currentIndex].last(where: { $0.type == type }) {
            return element
        }
        if let parent = parentElement {
            return parent.parentList.previous(ofType: type)
        }
        return nil
    }
    
    // Search for the next visible element with the given display label
    func next(withLabel label: String) -> Element? {
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
        currentIndex = 0;
        // Don't use for loop here as the list may be modified while reading
        while currentIndex < elements.count && reader.position < reader.data.endIndex {
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
