import Cocoa
import RFSupport

class ElementList {
    private(set) weak var parentElement: Element?
    private(set) weak var controller: TemplateWindowController!
    private var elements: [Element] = []
    private var visibleElements: [Element] = []
    private var currentIndex = 0
    private var configured = false
    var count: Int {
        return visibleElements.count
    }
    
    init(controller: TemplateWindowController, parent: Element? = nil) {
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
    
    func readTemplate(data: Data) -> Bool {
        do {
            let reader = BinaryDataReader(data)
            while reader.position < reader.data.endIndex {
                if let element = try self.readElement(from: reader) {
                    elements.append(element)
                }
            }
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
    func subList(for startElement: Element) throws -> ElementList {
        let list = ElementList(controller: controller, parent: startElement)
        var nesting = 0
        while true {
            guard let element = self.pop() else {
                throw TemplateError.unclosedElement(startElement)
            }
            if element.endType == startElement.endType {
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
    
    // MARK: -
    
    func readElement(from reader: BinaryDataReader) throws -> Element? {
        guard let label = try? reader.readPString(),
              let typeCode: FourCharCode = try? reader.read()
        else {
            throw TemplateError.corrupt
        }
        let type = typeCode.stringValue
        
        var elType = Self.fieldRegistry[type]
        
        // check for Xnnn type - currently using resorcerer's nmm restriction to reserve all-alpha types (e.g. FACE) for potential future use
        if elType == nil && type.range(of: "[A-Z](?!000)[0-9][0-9A-F]{2}", options: .regularExpression) != nil {
            if type.first == "R" {
                // Rnnn psuedo-element repeats the following element n times
                let count = Int(type.suffix(3), radix: 16)!
                let offset = Int(label.split(separator: "=").last!) ?? 1
                guard var el = try self.readElement(from: reader) else {
                    throw TemplateError.corrupt
                }
                let l = el.label
                for i in 0..<count {
                    // Replace * symbol with index
                    let label = l.replacingOccurrences(of: "*", with: String(i+offset))
                    el = Swift.type(of: el).init(type: el.type, label: label, tooltip: el.tooltip)!
                    elements.append(el)
                }
                return nil
            }
            elType = Self.fieldRegistry[String(type.prefix(1))]
        }
        
        // check for XXnn type
        if elType == nil && type.range(of: "[A-Z]{2}(?!00)[0-9]{2}", options: .regularExpression) != nil {
            elType = Self.fieldRegistry[String(type.prefix(2))]
        }
        if let elType = elType, let el = elType.init(type: type, label: label) {
            return el
        } else {
            throw TemplateError.unknownElement(type)
        }
    }
    
    static let fieldRegistry: [String: Element.Type] = [
        // integers
        "DBYT": ElementDBYT<Int8>.self,     // signed ints
        "DWRD": ElementDBYT<Int16>.self,
        "DLNG": ElementDBYT<Int32>.self,
//        "DLLG": ElementDBYT<Int64>.self,    // (ResForge)
        "UBYT": ElementDBYT<UInt8>.self,    // unsigned ints
        "UWRD": ElementDBYT<UInt16>.self,
        "ULNG": ElementDBYT<UInt32>.self,
//        "ULLG": ElementDBYT<UInt64>.self,   // (ResForge)
        "HBYT": ElementHBYT<UInt8>.self,    // hex byte/word/long
        "HWRD": ElementHBYT<UInt16>.self,
        "HLNG": ElementHBYT<UInt32>.self,
//        "HLLG": ElementHBYT<UInt64>.self,   // (ResForge)

        // multiple fields
        "RECT": ElementRECT.self,           // QuickDraw rect
        "PNT ": ElementPNT.self,            // QuickDraw point

        // align & fill
        "AWRD": ElementAWRD.self,           // alignment ints
        "ALNG": ElementAWRD.self,
        "AL08": ElementAWRD.self,
        "AL16": ElementAWRD.self,
        "FBYT": ElementFBYT.self,           // filler ints
        "FWRD": ElementFBYT.self,
        "FLNG": ElementFBYT.self,
        "FLLG": ElementFBYT.self,
        "F"   : ElementFBYT.self,           // Fnnn

        // fractions
        "REAL": ElementREAL.self,           // single precision float
        "DOUB": ElementDOUB.self,           // double precision float

        // strings
        "PSTR": ElementPSTR<UInt8>.self,
        "BSTR": ElementPSTR<UInt8>.self,
        "WSTR": ElementPSTR<UInt16>.self,
        "LSTR": ElementPSTR<UInt32>.self,
        "OSTR": ElementPSTR<UInt8>.self,
        "ESTR": ElementPSTR<UInt8>.self,
        "CSTR": ElementPSTR<UInt32>.self,
        "OCST": ElementPSTR<UInt32>.self,
        "ECST": ElementPSTR<UInt32>.self,
        "TXTS": ElementPSTR<UInt32>.self,
        "P"   : ElementPSTR<UInt8>.self,    // Pnnn
        "C"   : ElementPSTR<UInt32>.self,   // Cnnn
        "T"   : ElementPSTR<UInt32>.self,   // Tnnn
        "CHAR": ElementCHAR.self,
        "TNAM": ElementTNAM.self,

        // bits
        "BOOL": ElementBOOL.self,           // true = 256; false = 0
        "BFLG": ElementBFLG<UInt8>.self,    // binary flag the size of a byte/word/long
        "WFLG": ElementBFLG<UInt16>.self,
        "LFLG": ElementBFLG<UInt32>.self,
        "BBIT": ElementBBIT<UInt8>.self,    // bit within a byte
        "BB"  : ElementBBIT<UInt8>.self,    // BBnn bit field
        "BF"  : ElementBBIT<UInt8>.self,    // BFnn fill bits (ResForge)
        "WBIT": ElementBBIT<UInt16>.self,
        "WB"  : ElementBBIT<UInt16>.self,   // WBnn
        "WF"  : ElementBBIT<UInt16>.self,   // WFnn (ResForge)
        "LBIT": ElementBBIT<UInt32>.self,
        "LB"  : ElementBBIT<UInt32>.self,   // LBnn
        "LF"  : ElementBBIT<UInt32>.self,   // LFnn (ResForge)
        "BORV": ElementBORV<UInt8>.self,    // OR-value (Rezilla)
        "WORV": ElementBORV<UInt16>.self,
        "LORV": ElementBORV<UInt32>.self,

        // hex dumps
        "HEXD": ElementHEXD.self,
        "HEXS": ElementHEXD.self,
        "H"   : ElementHEXD.self,           // Hnnn
        "BHEX": ElementBHEX<UInt8>.self,
        "WHEX": ElementBHEX<UInt16>.self,
        "LHEX": ElementBHEX<UInt32>.self,
        "BSHX": ElementBHEX<UInt8>.self,
        "WSHX": ElementBHEX<UInt16>.self,
        "LSHX": ElementBHEX<UInt32>.self,

        // list counters
        "BCNT": ElementOCNT<UInt8>.self,
        "OCNT": ElementOCNT<UInt16>.self,
        "LCNT": ElementOCNT<UInt32>.self,
        "ZCNT": ElementOCNT<Int16>.self,
        "LZCT": ElementOCNT<Int32>.self,
        "FCNT": ElementFCNT.self,           // fixed count with count in label (why didn't they choose Lnnn?)
        "R"   : Element.self,               // single-element repeat (ResForge) (never initialised but included here for reference)
        // list begin/end
        "LSTB": ElementLSTB.self,
        "LSTS": ElementLSTB.self,
        "LSTZ": ElementLSTB.self,
        "LSTC": ElementLSTB.self,
        "LSTE": Element.self,

        // option lists
        "CASE": ElementCASE.self,           // single option for preceding element
        "CASR": ElementCASR.self,           // option range for preceding element (ResForge)
        "RSID": ElementRSID.self,           // resouce id (signed word) - type and offset in label

        // key selectors
        "KBYT": ElementKBYT<Int8>.self,     // signed keys
        "KWRD": ElementKBYT<Int16>.self,
        "KLNG": ElementKBYT<Int32>.self,
//        "KLLG": ElementKBYT<Int64>.self,    // (ResForge)
        "KUBT": ElementKBYT<UInt8>.self,    // unsigned keys
        "KUWD": ElementKBYT<UInt16>.self,
        "KULG": ElementKBYT<UInt32>.self,
//        "KULL": ElementKBYT<UInt64>.self,   // (ResForge)
        "KHBT": ElementKHBT<UInt8>.self,    // hex keys
        "KHWD": ElementKHBT<UInt16>.self,
        "KHLG": ElementKHBT<UInt32>.self,
//        "KHLL": ElementKHBT<UInt64>.self,   // (ResForge)
        "KCHR": ElementKCHR.self,           // string keys
        "KTYP": ElementKTYP.self,
        "KRID": ElementKRID.self,           // key on ID of the resource
        // keyed section begin/end
        "KEYB": ElementKEYB.self,
        "KEYE": Element.self,

        // dates
        "DATE": ElementDATE.self,           // 4-byte date (seconds since 1 Jan 1904)
        "MDAT": ElementDATE.self,

        // colours
        "COLR": ElementCOLR.self,           // 6-byte QuickDraw colour
        "WCOL": ElementWCOL<UInt16>.self,   // 2-byte (15-bit) colour (Rezilla)
        "LCOL": ElementWCOL<UInt32>.self,   // 4-byte (24-bit) colour (Rezilla)
        
        // offsets
        "BSKP": ElementBSKP<UInt8>.self,
        "WSKP": ElementBSKP<UInt16>.self,
        "SKIP": ElementBSKP<UInt16>.self,
        "LSKP": ElementBSKP<UInt32>.self,
        "BSIZ": ElementBSKP<UInt8>.self,
        "WSIZ": ElementBSKP<UInt16>.self,
        "LSIZ": ElementBSKP<UInt32>.self,
        "SKPE": Element.self,
        
        // byte order
        "BIGE": ElementBNDN.self,           // Big-endian
        "LTLE": ElementBNDN.self,           // Little-endian
        "BNDN": ElementBNDN.self,           // Big-endian (hidden)
        "LNDN": ElementBNDN.self,           // Little-endian (hidden)

        // cosmetic
        "DVDR": ElementDVDR.self,           // divider
        "RREF": ElementRREF.self,           // static reference to another resource (ResForge)
        "PACK": ElementPACK.self,           // pack other elements together (ResForge)

        // and some faked ones just to increase compatibility
        "SFRC": ElementDBYT<UInt16>.self,   // 0.16 fixed fraction
        "FXYZ": ElementDBYT<UInt16>.self,   // 1.15 fixed fraction
        "FWID": ElementDBYT<UInt16>.self,   // 4.12 fixed fraction
        "FRAC": ElementDBYT<UInt32>.self,   // 2.30 fixed fraction
        "FIXD": ElementDBYT<UInt32>.self,   // 16.16 fixed fraction
        "SCPC": ElementDBYT<Int16>.self,    // MacOS script code (ScriptCode)
        "LNGC": ElementDBYT<Int16>.self,    // MacOS language code (LangCode)
        "RGNC": ElementDBYT<Int16>.self,    // MacOS region code (RegionCode)
        "CODE": ElementHEXD.self            // 680x0 Disassembled Code Dump
    ]
}
