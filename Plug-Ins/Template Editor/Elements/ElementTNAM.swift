import RKSupport

class ElementTNAM: ElementDBYT<UInt32> {
    // This is marked as dynamic so that RSID can bind to it and receive changes
    @objc dynamic private var value: String {
        get { tValue.stringValue }
        set { tValue = FourCharCode(newValue) }
    }
    
    override func configure() throws {
        try super.configure()
        self.width = 60
    }
    
    override class var formatter: Formatter? {
        let formatter = MacRomanFormatter()
        formatter.stringLength = 4
        formatter.exactLengthRequired = true
        return formatter
    }
}
