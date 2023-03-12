import Cocoa
import RFSupport

// Implements LSTB, LSTZ, LSTC, LSTS
class ElementLSTB: Element, CollectionElement {
    let endType = "LSTE"
    weak var counter: CounterElement?
    var fixedCount: Bool = false
    private let zeroTerminated: Bool
    private var subElements: ElementList!
    private var entries: [Element]!
    private weak var tail: ElementLSTB!
    private(set) var singleElement: Element?

    override var displayLabel: String {
        get {
            guard tail != nil else {
                return super.displayLabel
            }
            let index = entries?.endIndex ?? tail.entries.firstIndex(of: self)!
            if tail == self {
                return "\(index+1))"
            } else {
                return "\(index+1)) " + (singleElement?.displayLabel ?? super.displayLabel)
            }
        }
        set {
            super.displayLabel = newValue
        }
    }

    required init(type: String, label: String) {
        zeroTerminated = type == "LSTZ"
        super.init(type: type, label: label)
        self.rowHeight = 18
    }

    override func copy() -> Self {
        let element = (super.copy() as Element) as! Self
        element.subElements = try? subElements?.copy()
        element.checkSingleElement()
        element.fixedCount = fixedCount
        element.tail = tail
        return element
    }

    override func configure() throws {
        guard type != "LSTC" || counter != nil  else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Preceeding count element not found.", comment: ""))
        }
        subElements = try self.parentList.subList(for: self)
        if type == "LSTB" || type == "LSTS" {
            guard self.isAtEnd() else {
                throw TemplateError.unboundedElement(self)
            }
        }
        _ = try subElements.copy() // Validate the subElements configuration
        // This item will be the tail
        tail = self
        entries = [] // Don't include tail in the list as this will create a reference cycle
        if fixedCount {
            // Fixed count list, create all the entries now
            for _ in 0..<counter!.count {
                self.parentList.insert(self.createNext())
            }
        }
    }

    // If the list entry contains only a single visible element, show that element here while hiding the sub section
    // (this also greatly improves performance with large lists)
    override func configure(view: NSView) {
        singleElement?.configure(view: view)
    }

    private func checkSingleElement() {
        if subElements != nil && subElements.count == 1 {
            singleElement = subElements.element(at: 0)
            self.subtext = singleElement!.subtext
            self.width = singleElement!.width
            self.rowHeight = singleElement!.rowHeight
        }
    }

    func createNext() -> Self {
        // Create a new list entry, inserting before self
        let list = self.copy() as Self
        tail.entries.append(list)
        return list
    }

    override func readData(from reader: BinaryDataReader) throws {
        if tail != self {
            try subElements.readData(from: reader)
        } else if counter == nil {
            while reader.position < reader.data.endIndex {
                if zeroTerminated && reader.data[reader.position] == 0 {
                    try reader.advance(1)
                    break
                }
                let list = self.createNext()
                self.parentList.insert(list)
                try list.subElements.readData(from: reader)
            }
        }
    }

    override func writeData(to writer: BinaryDataWriter) {
        if tail != self {
            subElements.writeData(to: writer)
        } else if zeroTerminated {
            writer.advance(1)
        }
    }

    // MARK: -

    var subElementCount: Int {
        if let single = singleElement {
            return (single as? CollectionElement)?.subElementCount ?? 0
        }
        return tail == self ? 0 : subElements.count
    }

    func subElement(at index: Int) -> Element {
        return (singleElement as? CollectionElement)?.subElement(at: index) ?? subElements.element(at: index)
    }

    func allowsCreateListEntry() -> Bool {
        return !fixedCount
    }

    func allowsRemoveListEntry() -> Bool {
        return !fixedCount && tail != self
    }

    func createListEntry() {
        let list = tail.copy() as ElementLSTB
        parentList.insert(list, before: self)
        let index = entries?.endIndex ?? tail.entries.firstIndex(of: self)!
        tail.entries.insert(list, at: index)
        tail.counter?.count += 1
    }

    func removeListEntry() {
        parentList.remove(self)
        tail.entries.removeAll(where: { $0 == self })
        tail.counter?.count -= 1
    }
}
