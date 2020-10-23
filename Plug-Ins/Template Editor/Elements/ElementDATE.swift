import Cocoa

class ElementDATE: ElementUBYT<UInt32> {
    static var hfsToRef: Double = 2082844800+978307200 // Seconds between 1904 and 2001
    
    override func configure() throws {
        self.width = 240
        self.value = UInt(Date().timeIntervalSinceReferenceDate + Self.hfsToRef)
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
        picker.bind(.value, to: self, withKeyPath: "value", options: [.valueTransformer: self])
        view.addSubview(picker)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return Double(value as! UInt) - Self.hfsToRef
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return UInt((value as! Date).timeIntervalSinceReferenceDate + Self.hfsToRef)
    }
}
