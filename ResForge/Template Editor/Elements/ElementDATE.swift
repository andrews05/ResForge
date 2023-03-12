import Cocoa
import RFSupport

class ElementDATE: Element {
    static var hfsToRef: Double = 2082844800+978307200 // Seconds between 1904 and 2001
    private var tValue: UInt32 = 0
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
        frame.origin.y -= 1
        frame.size.width = self.width-4
        frame.size.height = 24
        let picker = NSDatePicker(frame: frame)
        picker.minDate = Date(timeIntervalSinceReferenceDate: -Self.hfsToRef)
        picker.maxDate = Date(timeIntervalSinceReferenceDate: Double(UInt32.max)-Self.hfsToRef)
        picker.timeZone = TimeZone(secondsFromGMT: 0)
        picker.font = NSFont.systemFont(ofSize: 12)
        picker.drawsBackground = true
        picker.action = #selector(TemplateEditor.itemValueUpdated(_:))
        picker.bind(.value, to: self, withKeyPath: "value")
        view.addSubview(picker)
    }

    override func readData(from reader: BinaryDataReader) throws {
        tValue = try reader.read()
    }

    override func writeData(to writer: BinaryDataWriter) {
        writer.write(tValue)
    }
}
