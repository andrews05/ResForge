import Foundation
import RFSupport

struct DITLItem {
    enum DITLItemType : UInt8 {
        case userItem = 0
        case helpItem = 1
        case button = 4
        case checkBox = 5
        case radioButton = 6
        case control = 7
        case staticText = 8
        case editText = 16
        case icon = 32
        case picture = 64
        case unknown = 255

        var title: String {
            switch self {
            case .userItem: "User Item"
            case .helpItem: "Help Item"
            case .button: "Button"
            case .checkBox: "Check Box"
            case .radioButton: "Radio Button"
            case .control: "Control"
            case .staticText: "Static Text"
            case .editText: "Edit Text"
            case .icon: "Icon"
            case .picture: "Picture"
            case .unknown: "Unknown"
            }
        }
    }
    
    enum DITLHelpItemType : UInt16 {
        case unknown = 0
        case HMScanhdlg = 1
        case HMScanhrct = 2
        case HMScanAppendhdlg = 8
    }
    
    var itemView: DITLItemView
    var enabled: Bool
    var itemType: DITLItemType
    var resourceID: Int // Only SInt16, but let's be consistent with ResForge's Resource type.
    var helpItemType = DITLHelpItemType.unknown
    var itemNumber = Int16(0)

    static func read(_ reader: BinaryDataReader, manager: RFEditorManager) throws -> DITLItem {
        try reader.advance(4)
        let t: Int16 = try reader.read()
        let l: Int16 = try reader.read()
        let b: Int16 = try reader.read()
        let r: Int16 = try reader.read()
        let typeAndEnableFlag: UInt8 = try reader.read()
        let isEnabled = (typeAndEnableFlag & 0b10000000) == 0b10000000
        let rawItemType: UInt8 = typeAndEnableFlag & 0b01111111
        let itemType = DITLItem.DITLItemType(rawValue: rawItemType ) ?? .unknown
        var helpItemType = DITLHelpItemType.unknown
        var itemNumber = Int16(0)
        
        var text = ""
        var resourceID: Int = 0
        switch itemType {
        case .checkBox, .radioButton, .button, .staticText:
            text = try reader.readPString()
        case .editText:
            text = try reader.readPString()
        case .control, .icon, .picture:
            try reader.advance(1)
            let resID16: Int16 = try reader.read()
            resourceID = Int(resID16)
        case .helpItem:
            try reader.advance(1)
            helpItemType = DITLHelpItemType(rawValue: try reader.read()) ?? .unknown
            let resID16: Int16 = try reader.read()
            resourceID = Int(resID16)
            if helpItemType == .HMScanAppendhdlg {
                itemNumber = try reader.read()
            }
        case .userItem:
            let reserved: UInt8 = try reader.read()
            try reader.advance(Int(reserved))
        default:
            let reserved: UInt8 = try reader.read()
            try reader.advance(Int(reserved))
        }
        if (reader.bytesRead % 2) != 0 {
            try reader.advance(1)
        }
        
        let view = DITLItemView(rawFrame: NSRect(origin: NSPoint(x: Double(l), y: Double(t)), size: NSSize(width: Double(r &- l), height: Double(b &- t))), title: text, type: itemType, enabled: isEnabled, resourceID: resourceID, manager: manager)
        return DITLItem(itemView: view, enabled: isEnabled, itemType: itemType, resourceID: resourceID, helpItemType: helpItemType, itemNumber: itemNumber)
    }
    
    func write(to writer: BinaryDataWriter) throws {
        writer.write(UInt32(0))
        let box = itemView.rawFrame
        
        writer.write(Int16(clamping: Int(box.minY)))
        writer.write(Int16(clamping: Int(box.minX)))
        writer.write(Int16(clamping: Int(box.maxY)))
        writer.write(Int16(clamping: Int(box.maxX)))
        writer.write(UInt8(itemType.rawValue | (itemView.enabled ? 0b10000000 : 0)))
        
        switch itemType {
        case .checkBox, .radioButton, .button, .staticText:
            try writer.writePString(itemView.title)
        case .editText:
            try writer.writePString(itemView.title)
        case .control, .icon, .picture:
            writer.write(UInt8(2))
            writer.write(Int16(resourceID))
        case .helpItem:
            writer.write(UInt8((helpItemType == .HMScanAppendhdlg) ? 6 : 4))
            writer.write(helpItemType.rawValue)
            writer.write(Int16(resourceID))
            if helpItemType == .HMScanAppendhdlg {
                writer.write(Int16(itemNumber))
            }
        case .userItem:
            writer.write(UInt8(0))
        default:
            writer.write(UInt8(0))
        }
        if (writer.bytesWritten % 2) != 0 {
            writer.write(UInt8(0))
        }
    }
}
