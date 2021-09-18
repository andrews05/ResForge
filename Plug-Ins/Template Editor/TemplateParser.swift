import RFSupport

class TemplateParser {
    private let template: Resource
    private let manager: RFEditorManager
    private let basic: Bool
    private let registry: [String: Element.Type]
    private let reader: BinaryDataReader
    
    init(template: Resource, manager: RFEditorManager, basic: Bool = false) {
        self.template = template
        self.manager = manager
        self.basic = basic
        self.registry = basic ? Self.basicRegistry : Self.fullRegistry
        self.reader = BinaryDataReader(template.data)
    }
    
    func parse() throws -> [Element] {
        var elements: [Element] = []
        while reader.position < reader.data.endIndex {
            elements += try self.process()
        }
        return elements
    }
    
    private func process() throws -> [Element] {
        let (element, type) = try self.readElement()
        switch type {
        case "TMPL":
            // Insert another template's data
            guard !element.label.isEmpty else {
                throw TemplateError.invalidStructure(element, "Template name must not be blank.")
            }
            guard element.label != template.name else {
                throw TemplateError.invalidStructure(element, "Cannot include self.")
            }
            guard let template = manager.findResource(type: ResourceType.Template, name: element.label, currentDocumentOnly: false) else {
                throw TemplateError.invalidStructure(element, "Template could not be found.")
            }
            return try TemplateParser(template: template, manager: manager, basic: basic).parse()
        case "R":
            // Rnnn psuedo-element repeats the following element n times
            let count = Element.variableTypeValue(element.type)
            let offset = Int(element.meta) ?? 1
            let els = try self.process()
            var elements: [Element] = []
            for i in 0..<count {
                for el in els {
                    // Replace * symbol with index
                    let label = el.label.replacingOccurrences(of: "*", with: String(i+offset))
                    let newEl = Swift.type(of: el).init(type: el.type, label: label)!
                    elements.append(newEl)
                }
            }
            return elements
        case "RECT", "PNT ":
            // In basic mode, expand to multiple DWRDs
            if !basic {
                fallthrough
            }
            let fields = type == "RECT" ? ["T", "L", "B", "R"] : ["X", "Y"]
            let dwrd = registry["DWRD"]!
            var elements: [Element] = []
            for f in fields {
                // Replace * symbol with index
                let newEl = dwrd.init(type: "DWRD", label: "\(element.label) \(f)")!
                elements.append(newEl)
            }
            return elements
        default:
            return [element]
        }
    }
    
    private func readElement() throws -> (Element, String) {
        guard let label = try? reader.readPString(),
              let type = try? reader.readString(length: 4, encoding: .macOSRoman)
        else {
            throw TemplateError.corrupt
        }
        var baseType = type
        
        // check for Xnnn type - currently using resorcerer's nmm restriction to reserve all-alpha types (e.g. FACE) for potential future use
        if registry[baseType] == nil && type.range(of: "[A-Z](?!000)[0-9][0-9A-F]{2}", options: .regularExpression) != nil {
            baseType = String(type.prefix(1))
        }
        // check for XXnn type
        if registry[baseType] == nil && type.range(of: "[A-Z]{2}(?!00)[0-9]{2}", options: .regularExpression) != nil {
            baseType = String(type.prefix(2))
        }
        
        if let elType = registry[baseType], let el = elType.init(type: type, label: label) {
            return (el, baseType)
        }
        throw TemplateError.unknownElement(type)
    }
    
    // basic types that can be represented by (e.g.) csv
    static let basicRegistry: [String: Element.Type] = [
        // integers
        "DBYT": ElementDBYT<Int8>.self,     // signed ints
        "DWRD": ElementDBYT<Int16>.self,
        "DLNG": ElementDBYT<Int32>.self,
        "DQWD": ElementDBYT<Int64>.self,    // (ResForge)
        "UBYT": ElementDBYT<UInt8>.self,    // unsigned ints
        "UWRD": ElementDBYT<UInt16>.self,
        "ULNG": ElementDBYT<UInt32>.self,
        "UQWD": ElementDBYT<UInt64>.self,   // (ResForge)
        "HBYT": ElementHBYT<UInt8>.self,    // hex byte/word/long
        "HWRD": ElementHBYT<UInt16>.self,
        "HLNG": ElementHBYT<UInt32>.self,
        "HQWD": ElementHBYT<UInt64>.self,   // (ResForge)
        
        // multiple fields
        "RECT": ElementRECT.self,           // QuickDraw rect
        "PNT ": ElementPNT.self,            // QuickDraw point
        
        // fractions
        "REAL": ElementREAL.self,           // single precision float
        "DOUB": ElementDOUB.self,           // double precision float
        "FIXD": ElementFIXD.self,           // 16:16 fixed precision
        
        // strings
        "PSTR": ElementPSTR<UInt8>.self,    // Pascal string
        "BSTR": ElementPSTR<UInt8>.self,
        "WSTR": ElementPSTR<UInt16>.self,
        "LSTR": ElementPSTR<UInt32>.self,
        "ESTR": ElementPSTR<UInt8>.self,
        "OSTR": ElementPSTR<UInt8>.self,
        "P"   : ElementPSTR<UInt8>.self,    // Pnnn
        "CSTR": ElementCSTR.self,           // C string
        "ECST": ElementCSTR.self,
        "OCST": ElementCSTR.self,
        "C"   : ElementCSTR.self,           // Cnnn
        "USTR": ElementUSTR.self,           // UTF-8 string (ResForge)
        "U"   : ElementUSTR.self,           // Unnn (ResForge)
        "T"   : ElementTXTS.self,           // Tnnn
        "CHAR": ElementCHAR.self,
        "TNAM": ElementTNAM.self,
        
        // align & fill
        "AWRD": ElementAWRD.self,           // alignment ints
        "ALNG": ElementAWRD.self,
        "AL08": ElementAWRD.self,
        "AL16": ElementAWRD.self,
        "FBYT": ElementFBYT.self,           // filler ints
        "FWRD": ElementFBYT.self,
        "FLNG": ElementFBYT.self,
        "F"   : ElementFBYT.self,           // Fnnn
        
        // byte order
        "BNDN": ElementBNDN.self,           // Big-endian (hidden)
        "LNDN": ElementBNDN.self,           // Little-endian (hidden)
        
        // psuedo-elements (handled by parser)
        "R"   : Element.self,               // single-element repeat (ResForge)
    ]
    
    static let fullRegistry: [String: Element.Type] = basicRegistry.merging([
        // strings
        "TXTS": ElementTXTS.self,           // sized text dump

        // bits
        "BOOL": ElementBOOL.self,           // true = 256; false = 0
        "BFLG": ElementBFLG<UInt8>.self,    // binary flag the size of a byte/word/long
        "WFLG": ElementBFLG<UInt16>.self,
        "LFLG": ElementBFLG<UInt32>.self,
        "BBIT": ElementBBIT<UInt8>.self,    // bit within a byte
        "BB"  : ElementBBIT<UInt8>.self,    // BBnn bit field
        "BF"  : ElementBBIT<UInt8>.self,    // BFnn fill bits (ResForge)
        "WBIT": ElementBBIT<UInt16>.self,
        "WB"  : ElementBBIT<UInt16>.self,
        "WF"  : ElementBBIT<UInt16>.self,
        "LBIT": ElementBBIT<UInt32>.self,
        "LB"  : ElementBBIT<UInt32>.self,
        "LF"  : ElementBBIT<UInt32>.self,
        "QBIT": ElementBBIT<UInt64>.self,   // (ResForge)
        "QB"  : ElementBBIT<UInt64>.self,
        "QF"  : ElementBBIT<UInt64>.self,
        "BORV": ElementBORV<UInt8>.self,    // OR-value (Rezilla)
        "WORV": ElementBORV<UInt16>.self,
        "LORV": ElementBORV<UInt32>.self,
        "QORV": ElementBORV<UInt64>.self,   // (ResForge)

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
        // list begin/end
        "LSTB": ElementLSTB.self,
        "LSTS": ElementLSTB.self,
        "LSTZ": ElementLSTB.self,
        "LSTC": ElementLSTB.self,
        "LSTE": Element.self,

        // option lists
        "CASE": ElementCASE.self,           // single option for preceding element
        "CASR": ElementCASR.self,           // option range for preceding element (ResForge)
        "RSID": ElementRSID<Int16>.self,    // resouce id - type and offset in label
        "LRID": ElementRSID<Int32>.self,    // long resouce id, for extended format (ResForge)

        // key selectors
        "KBYT": ElementKBYT<Int8>.self,     // signed keys
        "KWRD": ElementKBYT<Int16>.self,
        "KLNG": ElementKBYT<Int32>.self,
        "KQWD": ElementKBYT<Int64>.self,    // (ResForge)
        "KUBT": ElementKBYT<UInt8>.self,    // unsigned keys
        "KUWD": ElementKBYT<UInt16>.self,
        "KULG": ElementKBYT<UInt32>.self,
        "KUQD": ElementKBYT<UInt64>.self,   // (ResForge)
        "KHBT": ElementKHBT<UInt8>.self,    // hex keys
        "KHWD": ElementKHBT<UInt16>.self,
        "KHLG": ElementKHBT<UInt32>.self,
        "KHQD": ElementKHBT<UInt64>.self,   // (ResForge)
        "KCHR": ElementKCHR.self,           // string keys
        "KTYP": ElementKTYP.self,
        "KRID": ElementKRID.self,           // key on ID of the resource
        // keyed section begin/end
        "KEYB": ElementKEYB.self,
        "KEYE": Element.self,

        // dates
        "DATE": ElementDATE.self,           // 4-byte date (seconds since 1 Jan 1904)

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
        "BIGE": ElementBNDN.self,           // Big-endian (visible)
        "LTLE": ElementBNDN.self,           // Little-endian (visible)

        // cosmetic
        "DVDR": ElementDVDR.self,           // divider
        "RREF": ElementRREF.self,           // static reference to another resource (ResForge)
        "PACK": ElementPACK.self,           // pack other elements together (ResForge)
        
        // psuedo-elements (handled by parser)
        "TMPL": Element.self,               // include another template (ResForge)

        // and some faked ones just to increase compatibility
        "FRAC": ElementDBYT<UInt32>.self,   // 2:30 fixed precision
        "SFRC": ElementDBYT<UInt16>.self,   // 0.16 fixed fraction
        "FXYZ": ElementDBYT<UInt16>.self,   // 1.15 fixed fraction
        "FWID": ElementDBYT<UInt16>.self,   // 4.12 fixed fraction,
        "MDAT": ElementDATE.self,           // Modification date (same as DATE but Resorcerer will update on save)
        "SCPC": ElementDBYT<Int16>.self,    // MacOS script code (ScriptCode)
        "LNGC": ElementDBYT<Int16>.self,    // MacOS language code (LangCode)
        "RGNC": ElementDBYT<Int16>.self,    // MacOS region code (RegionCode)
        "CODE": ElementHEXD.self            // 680x0 Disassembled Code Dump
    ]) { $1 }
}
