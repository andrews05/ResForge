import Cocoa
import RKSupport

// Implements LSTB, LSTZ, LSTC
class ElementLSTB: Element {
    weak var counter: CounterElement?
    var fixedCount: Bool = false
    private let zeroTerminated: Bool
    private var subElements: ElementList!
    private var entries: [Element]!
    private weak var tail: ElementLSTB!
    private var singleElement: Element?
    
    override var displayLabel: String {
        guard tail != nil else {
            return super.displayLabel
        }
        let index = entries?.endIndex ?? tail.entries.firstIndex(of: self)!
        return "\(index+1)) " + (singleElement?.displayLabel ?? super.displayLabel)
    }
    
    required init(type: String, label: String, tooltip: String? = nil) {
        zeroTerminated = type == "LSTZ"
        super.init(type: type, label: label, tooltip: tooltip)
        self.rowHeight = 18
        self.endType = "LSTE"
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
        guard type != "LSTB" || (self.parentList.parentList == nil && self.parentList.peek(1) == nil) else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Closing ‘LSTE’ must be last element in template.", comment: ""))
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
            self.tooltip = singleElement!.tooltip
            self.rowHeight = 22
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
    
    override func dataSize(_ size: inout Int) {
        if tail != self {
            subElements.dataSize(&size)
        } else if zeroTerminated {
            size += 1
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
    
    override var hasSubElements: Bool {
        singleElement?.hasSubElements ?? (tail != self)
    }
    
    override var subElementCount: Int {
        singleElement?.subElementCount ?? subElements.count
    }
    
    override func subElement(at index: Int) -> Element {
        return singleElement?.subElement(at: index) ?? subElements.element(at: index)
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
