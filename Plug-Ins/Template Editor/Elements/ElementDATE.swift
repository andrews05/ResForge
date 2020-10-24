import Cocoa

class ElementDATE: ElementDBYT<UInt32> {
    static var hfsToRef: Double = 2082844800+978307200 // Seconds between 1904 and 2001
    @objc private var value: Date {
        get { Date(timeIntervalSinceReferenceDate: Double(tValue) - Self.hfsToRef) }
        set { tValue = UInt32(newValue.timeIntervalSinceReferenceDate + Self.hfsToRef) }
    }
    
    override func configure() throws {
        self.width = 240
        self.value = Date()
        self.tValue += UInt32(TimeZone.current.secondsFromGMT())
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.size.width = self.width-4
        let picker = NSDatePicker(frame: frame)
        picker.minDate = Date(timeIntervalSinceReferenceDate: -Self.hfsToRef)
        picker.maxDate = Date(timeIntervalSinceReferenceDate: Double(UInt32.max)-Self.hfsToRef)
        picker.timeZone = TimeZone(secondsFromGMT: 0)
        picker.font = NSFont.systemFont(ofSize: 12)
        picker.drawsBackground = true
        picker.action = #selector(TemplateWindowController.itemValueUpdated(_:))
        picker.bind(.value, to: self, withKeyPath: "value")
        view.addSubview(picker)
    }
}
