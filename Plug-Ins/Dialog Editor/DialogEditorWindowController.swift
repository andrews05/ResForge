import Cocoa
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
	}
	
	var itemView: DITLItemView
	var enabled: Bool
	var itemType: DITLItemType
	var resourceID: Int // Only SInt16, but let's be consistent with ResForge's Resource type.
	var helpItemType = Int16(0)
	var itemNumber = Int16(0)

	static func read(_ reader: BinaryDataReader, manager: RFEditorManager) -> DITLItem {
		try! reader.advance(4)
		var t: Int16 = try! reader.read()
		var l: Int16 = try! reader.read()
		var b: Int16 = try! reader.read()
		var r: Int16 = try! reader.read()
		let typeAndEnableFlag: UInt8 = try! reader.read()
		let isEnabled = (typeAndEnableFlag & 0b10000000) == 0b10000000
		let rawItemType: UInt8 = typeAndEnableFlag & 0b01111111
		let itemType = DITLItem.DITLItemType(rawValue: rawItemType ) ?? .unknown
		var helpItemType = Int16(0)
		var itemNumber = Int16(0)
		
		var text = ""
		var resourceID: Int = 0
		switch itemType {
		case .checkBox, .radioButton, .button, .staticText:
			text = try! reader.readPString()
		case .editText:
			l -= 3;
			t -= 3;
			r += 3;
			b += 3;
			text = try! reader.readPString()
		case .control, .icon, .picture:
			try! reader.advance(1)
			let resID16: Int16 = try! reader.read()
			resourceID = Int(resID16)
		case .helpItem:
			try! reader.advance(1)
			helpItemType = try! reader.read()
			let resID16: Int16 = try! reader.read()
			resourceID = Int(resID16)
			if helpItemType == 8 /* HMScanAppendhdlg */ {
				itemNumber = try! reader.read()
			} // else HMScanhdlg or HMScanhrct
		case .userItem:
			let reserved: UInt8 = try! reader.read()
			try! reader.advance(Int(reserved))
		default:
			let reserved: UInt8 = try! reader.read()
			try! reader.advance(Int(reserved))
		}
		if (reader.bytesRead % 2) != 0 {
			try! reader.advance(1)
		}

		let view = DITLItemView(frame: NSRect(origin: NSPoint(x: Double(l), y: Double(t)), size: NSSize(width: Double(r &- l), height: Double(b &- t))), title: text, type: itemType, enabled: isEnabled, resourceID: resourceID, manager: manager)
		return DITLItem(itemView: view, enabled: isEnabled, itemType: itemType, resourceID: resourceID, helpItemType: helpItemType, itemNumber: itemNumber)
	}
	
	func write(to writer: BinaryDataWriter) {
		writer.write(UInt32(0))
		let box = itemView.frame
		var t = Int16(box.minY)
		var l = Int16(box.minX)
		var b = Int16(box.maxY)
		var r = Int16(box.maxX)
		
		if itemType == .editText {
			l += 3;
			t += 3;
			r += 3;
			b += 3;
		}
		
		writer.write(t)
		writer.write(l)
		writer.write(b)
		writer.write(r)
		writer.write(UInt8(itemType.rawValue | (itemView.enabled ? 0b10000000 : 0)))
		
		switch itemType {
		case .checkBox, .radioButton, .button, .staticText:
			try! writer.writePString(itemView.title)
		case .editText:
			try! writer.writePString(itemView.title)
		case .control, .icon, .picture:
			writer.write(UInt8(2))
			writer.write(Int16(resourceID))
		case .helpItem:
			writer.write(UInt8((helpItemType == 8) ? 6 : 4))
			writer.write(Int16(resourceID))
			if helpItemType == 8 /* HMScanAppendhdlg */ {
				writer.write(Int16(itemNumber))
			}
		case .userItem:
			writer.write(UInt8(0))
		default:
			writer.write(UInt8(0))
		}
	}
}

class DialogEditorWindowController: AbstractEditor, ResourceEditor {
	static let supportedTypes = [
		"DITL",
	]
	
	let resource: Resource
	private let manager: RFEditorManager
	@IBOutlet var scrollView: NSScrollView!
	private var items = [DITLItem]()
	
	override var windowNibName: String {
		return "DialogEditorWindow"
	}
	
	required init(resource: Resource, manager: RFEditorManager) {
		self.resource = resource
		self.manager = manager
		super.init(window: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func windowDidLoad() {
		self.loadItems()
		self.updateView()
	}
		
	private func updateView() {
		var maxSize = NSSize(width: 128, height: 64)
		for item in items {
			self.scrollView.documentView?.addSubview(item.itemView)
			let itemBox = item.itemView.frame
			maxSize.width = max(itemBox.maxX, maxSize.width)
			maxSize.height = max(itemBox.maxY, maxSize.height)
		}
		var documentBox = self.scrollView.documentView?.frame ?? NSZeroRect
		documentBox.size.width = max(documentBox.size.width, maxSize.width + 16)
		documentBox.size.height = max(documentBox.size.height, maxSize.height + 16)
		self.scrollView.documentView?.frame = documentBox
		self.scrollView.documentView?.clipsToBounds = true
	}
	
	private func loadItems() {
		let reader = BinaryDataReader(resource.data)
		let itemCountMinusOne: UInt16 = try! reader.read()
		var itemCount: Int = Int(itemCountMinusOne) + 1
		
		while itemCount > 0 {
			let item = DITLItem.read(reader, manager: manager)
			items.append(item)

			itemCount -= 1
		}
	}
			
	@IBAction func saveResource(_ sender: Any) {
		self.setDocumentEdited(false)
	}
	
	@IBAction func revertResource(_ sender: Any) {
		self.loadItems()
		self.updateView()
		
		self.setDocumentEdited(false)
	}
				
}

public class DITLDocumentView : NSView {
	public override var isFlipped: Bool {
		get {
			return true
		}
		set(newValue) {
			
		}
	}
	public override func draw(_ dirtyRect: NSRect) {
		let fillColor = NSColor.white
		let strokeColor = NSColor.systemGray
		fillColor.setFill()
		strokeColor.setStroke()
		NSBezierPath.fill(self.bounds)
		NSBezierPath.stroke(self.bounds)
	}
}

/// View that shows a simple preview for a System 7 DITL item:
class DITLItemView : NSView {
	/// The text to display on the item (button title or text view text:
	var title: String
	/// Other info from the DITL resource about this item:
	var type: DITLItem.DITLItemType
	/// Is this object selected for editing/moving/resizing?
	var selected = false
	/// Resource referenced by this item (e.g. ICON ID for an icon item PICT for picture, CNTL for control etc.)
	var resourceID = 0
	/// Is this item clickable?
	var enabled: Bool
	/// Object that lets us look up icons and images.
	private let manager: RFEditorManager

	init(frame frameRect: NSRect, title: String, type: DITLItem.DITLItemType, enabled: Bool, resourceID: Int, manager: RFEditorManager) {
		self.title = title
		self.type = type
		self.enabled = enabled
		self.resourceID = resourceID
		self.manager = manager
		super.init(frame: frameRect)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func mouseDown(with event: NSEvent) {
		selected = !selected
		setNeedsDisplay(self.bounds)
	}
	
	override func draw(_ dirtyRect: NSRect) {
		switch type {
		case .userItem:
			let fillColor = (NSColor.systemBlue.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray).withAlphaComponent(0.7)
			let strokeColor = NSColor.systemBlue.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemBlue, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
			//		case .helpItem:
			//
		case .button:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			let lozenge = NSBezierPath(roundedRect: self.bounds, xRadius: 8.0, yRadius: 8.0)
			lozenge.fill()
			lozenge.stroke()
			
			let ps = NSMutableParagraphStyle()
			ps.alignment = .center
			let attrs: [NSAttributedString.Key:Any] = [.foregroundColor: strokeColor, .paragraphStyle: ps, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!]
			let measuredSize = title.size(withAttributes: attrs)
			var textBox = self.bounds
			textBox.origin.y -= (textBox.size.height - measuredSize.height) / 2
			title.draw(in: textBox, withAttributes: attrs)
		case .checkBox:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			var box = self.bounds
			box.size.width = box.size.height
			box = box.insetBy(dx: 2, dy: 2)
			NSBezierPath.stroke(box)
			NSBezierPath.fill(box)
			
			title.draw(at: NSPoint(x: box.maxX + 4, y: 0), withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .radioButton:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			var box = self.bounds
			box.size.width = box.size.height
			box = box.insetBy(dx: 2, dy: 2)
			let lozenge = NSBezierPath(ovalIn: box)
			lozenge.fill()
			lozenge.stroke()
			
			title.draw(at: NSPoint(x: box.maxX + 4, y: 0), withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .control:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
		case .staticText:
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.black, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .editText:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: strokeColor, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		case .icon:
			NSColor.darkGray.setFill()
			NSBezierPath.fill(self.bounds)
			var resource: Resource?
			resource = manager.findResource(type: ResourceType("cicn"), id: resourceID, currentDocumentOnly: true)
			if resource == nil {
				resource = manager.findResource(type: ResourceType("ICON"), id: resourceID, currentDocumentOnly: true)
			}
			if let resource = resource {
				var format: UInt32 = 0
				let imgRep = DITLItemView.imageRep(for: resource, format: &format)
				imgRep?.draw(in: self.bounds)
			}
		case .picture:
			NSColor.lightGray.setFill()
			NSBezierPath.fill(self.bounds)
			if let resource = manager.findResource(type: ResourceType("PICT"), id: resourceID, currentDocumentOnly: true) {
				var format: UInt32 = 0
				let imgRep = DITLItemView.imageRep(for: resource, format: &format)
				imgRep?.draw(in: self.bounds)
			}
		case .helpItem:
			let fillColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
			let strokeColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
		default:
			let fillColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
			let strokeColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemRed, .font: NSFontManager.shared.font(withFamily: "Silom", traits: [], weight: 0, size: 12.0)!])
		}
		
		if selected {
			NSColor.controlAccentColor.set()
			NSBezierPath.stroke(self.bounds)
			for knob in calculateKnobRects() {
				if let knob = knob {
					NSBezierPath.fill(knob)
				}
			}
		}
	}
	
	private static func imageRep(for resource: Resource, format: inout UInt32) -> NSImageRep? {
		let data = resource.data
		guard !data.isEmpty else {
			return nil
		}
		switch resource.typeCode {
		case "PICT":
			return self.rep(fromPict: data, format: &format)
		case "cicn":
			return QuickDraw.rep(fromCicn: data)
		case "ppat":
			return QuickDraw.rep(fromPpat: data)
		case "crsr":
			return QuickDraw.rep(fromCrsr: data)
		case "ICN#", "ICON":
			return Icons.rep(data, width: 32, height: 32, depth: 1)
		case "ics#", "SICN", "CURS":
			return Icons.rep(data, width: 16, height: 16, depth: 1)
		case "icm#":
			return Icons.rep(data, width: 16, height: 12, depth: 1)
		case "icl4":
			return Icons.rep(data, width: 32, height: 32, depth: 4)
		case "ics4":
			return Icons.rep(data, width: 16, height: 16, depth: 4)
		case "icm4":
			return Icons.rep(data, width: 16, height: 12, depth: 4)
		case "icl8":
			return Icons.rep(data, width: 32, height: 32, depth: 8)
		case "ics8":
			return Icons.rep(data, width: 16, height: 16, depth: 8)
		case "icm8":
			return Icons.rep(data, width: 16, height: 12, depth: 8)
		case "PAT ":
			return Icons.rep(data, width: 8, height: 8, depth: 1)
		case "PAT#":
			// This just stacks all the patterns vertically
			let count = Int(data[data.startIndex + 1])
			return Icons.rep(data.dropFirst(2), width: 8, height: 8 * count, depth: 1)
		default:
			return NSBitmapImageRep(data: data)
		}
	}
	
	private static func rep(fromPict data: Data, format: inout UInt32) -> NSImageRep? {
		do {
			return try QuickDraw.rep(fromPict: data, format: &format)
		} catch let error {
			// If the error is because of an unsupported QuickTime compressor, attempt to decode it
			// natively from the offset indicated. This should work for e.g. PNG, JPEG, GIF, TIFF.
			if let range = error.localizedDescription.range(of: "(?<=offset )[0-9]+", options: .regularExpression),
			   let offset = Int(error.localizedDescription[range]),
			   data.count > offset,
			   let rep = NSBitmapImageRep(data: data.dropFirst(offset)) {
				// Older QuickTime versions (<6.5) stored png data as non-standard RGBX
				// We need to disable the alpha, but first ensure the image has been decoded by accessing the bitmapData
				_ = rep.bitmapData
				rep.hasAlpha = false
				if let cRange = error.localizedDescription.range(of: "(?<=')....(?=')", options: .regularExpression) {
					format = UInt32(String(error.localizedDescription[cRange]))
				}
				return rep
			}
		}
		return nil
	}
	
	func calculateKnobRects() -> [NSRect?] {
		var result = [NSRect?]()
		var knobSize = 8.0
		let box = self.bounds
		var middleKnobs = true
		var minimalKnobs = false
		if ((knobSize * 2.0) + 1) >= box.size.height || ((knobSize * 2.0) + 1) >= box.size.width {
			minimalKnobs = true
		} else if ((knobSize * 3.0) + 2) >= box.size.height || ((knobSize * 3.0) + 2) > box.size.width {
			middleKnobs = false
		} else if (knobSize + 1) > box.size.height || (knobSize + 1) > box.size.width {
			knobSize = min(box.size.height - 1, box.size.width - 1)
		}

		var tlBox = self.bounds
		tlBox.size.width = knobSize
		tlBox.size.height = knobSize
		if !minimalKnobs {
			result.append(tlBox)
			if middleKnobs {
				tlBox.origin.x = box.midX - (tlBox.size.width / 2)
				result.append(tlBox)
			} else {
				result.append(nil)
			}
			if middleKnobs {
				tlBox.origin.x = 0
				tlBox.origin.y = box.midY - (tlBox.size.height / 2)
				result.append(tlBox)
			} else {
				result.append(nil)
			}
			tlBox.origin.x = 0
			tlBox.origin.y = box.maxY - tlBox.size.height
			result.append(tlBox)
			if middleKnobs {
				tlBox.origin.x = box.midX - (tlBox.size.width / 2)
				tlBox.origin.y = box.maxY - tlBox.size.height
				result.append(tlBox)
			} else {
				result.append(nil)
			}
			tlBox.origin.x = box.maxX - tlBox.size.width
			tlBox.origin.y = box.maxY - tlBox.size.height
			result.append(tlBox)
			if middleKnobs {
				tlBox.origin.x = box.maxX - tlBox.size.width
				tlBox.origin.y = box.midY - (tlBox.size.height / 2)
				result.append(tlBox)
			} else {
				result.append(nil)
			}
		}
		tlBox.origin.x = box.maxX - tlBox.size.width
		tlBox.origin.y = 0
		result.append(tlBox)
		
		return result
	}
}

/// View that makes our document view top-left aligned inside the scroll view:
class DITLFlippedClipView : NSClipView {
	public override var isFlipped: Bool {
		get {
			return true
		}
		set(newValue) {
			
		}
	}
}
