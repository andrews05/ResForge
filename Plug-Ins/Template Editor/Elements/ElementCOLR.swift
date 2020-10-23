import Cocoa
import RKSupport

class ElementCOLR: Element {
    var r: UInt16 = 0
    var g: UInt16 = 0
    var b: UInt16 = 0
    var mask: UInt = 0xFFFF
    
    @objc private var value: NSColor {
        get {
            return NSColor(red: CGFloat(r) / CGFloat(mask),
                           green: CGFloat(g) / CGFloat(mask),
                           blue: CGFloat(b) / CGFloat(mask),
                           alpha: 1)
        }
        set {
            r = UInt16(round(newValue.redComponent * CGFloat(mask)))
            g = UInt16(round(newValue.greenComponent * CGFloat(mask)))
            b = UInt16(round(newValue.blueComponent * CGFloat(mask)))
        }
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.size.width = self.width-4
        let well = NSColorWell(frame: frame)
        well.action = #selector(TemplateWindowController.itemValueUpdated(_:))
        well.bind(.value, to: self, withKeyPath: "value", options: nil)
        view.addSubview(well)
    }
    
    override func readData(from reader: BinaryDataReader) throws {
        r = try reader.read()
        g = try reader.read()
        b = try reader.read()
    }
    
    override func dataSize(_ size: inout Int) {
        size += 6
    }
    
    override func writeData(to writer: BinaryDataWriter) {
        writer.write(r)
        writer.write(g)
        writer.write(b)
    }
}
