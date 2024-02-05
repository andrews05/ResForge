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
			try! reader.advance(4)
			let t: Int16 = try! reader.read()
			let l: Int16 = try! reader.read()
			let b: Int16 = try! reader.read()
			let r: Int16 = try! reader.read()
			let typeAndEnableFlag: UInt8 = try! reader.read()
			let text = try! reader.readPString()
			if (reader.bytesRead % 2) != 0 {
				try! reader.advance(1)
			}
			let isEnabled = (typeAndEnableFlag & 0b10000000) == 0b10000000
			let itemType = DITLItem.DITLItemType(rawValue: typeAndEnableFlag & 0b01111111 ) ?? .unknown
			
			items.append(DITLItem(itemView: DITLItemView(frame: NSRect(origin: NSPoint(x: Double(l), y: Double(t)), size: NSSize(width: Double(r - l), height: Double(b - t))), title: text, type: itemType), enabled: isEnabled, itemType: itemType, resourceID: 0))

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
	
	init(frame frameRect: NSRect, title: String, type: DITLItem.DITLItemType) {
		self.title = title
		self.type = type
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
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemBlue])
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
			let attrs: [NSAttributedString.Key:Any] = [.foregroundColor: strokeColor, .paragraphStyle: ps]
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
			
			title.draw(at: NSPoint(x: box.maxX + 4, y: 0), withAttributes: [.foregroundColor: strokeColor])
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
			
			title.draw(at: NSPoint(x: box.maxX + 4, y: 0), withAttributes: [.foregroundColor: strokeColor])
		case .control:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
		case .staticText:
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.black])
		case .editText:
			let fillColor = NSColor.white
			let strokeColor = NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: strokeColor])
		case .icon:
			NSColor.darkGray.setFill()
			NSBezierPath.fill(self.bounds)
		case .picture:
			NSColor.lightGray.setFill()
			NSBezierPath.fill(self.bounds)
		case .unknown:
			let fillColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.controlBackgroundColor) ?? NSColor.lightGray
			let strokeColor = NSColor.systemRed.blended(withFraction: 0.4, of: NSColor.controlTextColor) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: nil)
		default:
			let fillColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.white) ?? NSColor.lightGray
			let strokeColor = NSColor.systemGreen.blended(withFraction: 0.4, of: NSColor.black) ?? NSColor.black
			fillColor.setFill()
			strokeColor.setStroke()
			NSBezierPath.fill(self.bounds)
			NSBezierPath.stroke(self.bounds)
			
			title.draw(at: NSZeroPoint, withAttributes: [.foregroundColor: NSColor.systemGreen])
		}
		
		if selected {
			var knobSize = 8.0
			let box = self.bounds
			var middleKnobs = true
			var minimalKnobs = false
			if ((knobSize * 2.0) + 1) >= box.size.height || ((knobSize * 2.0) + 1) >= box.size.width {
				minimalKnobs = true
			} else if ((knobSize * 3.0) + 2) >= box.size.height || ((knobSize * 3.0) + 2) > box.size.width {
				middleKnobs = false
			}
			NSColor.controlAccentColor.set()
			NSBezierPath.stroke(self.bounds)
			var tlBox = self.bounds
			tlBox.size.width = knobSize
			tlBox.size.height = knobSize
			if !minimalKnobs {
				NSBezierPath.fill(tlBox)
				if middleKnobs {
					tlBox.origin.x = box.midX - (tlBox.size.width / 2)
					NSBezierPath.fill(tlBox)
				}
				if middleKnobs {
					tlBox.origin.x = 0
					tlBox.origin.y = box.midY - (tlBox.size.height / 2)
					NSBezierPath.fill(tlBox)
				}
				tlBox.origin.x = 0
				tlBox.origin.y = box.maxY - tlBox.size.height
				NSBezierPath.fill(tlBox)
				if middleKnobs {
					tlBox.origin.x = box.midX - (tlBox.size.width / 2)
					tlBox.origin.y = box.maxY - tlBox.size.height
				}
				NSBezierPath.fill(tlBox)
				tlBox.origin.x = box.maxX - tlBox.size.width
				tlBox.origin.y = box.maxY - tlBox.size.height
				NSBezierPath.fill(tlBox)
				if middleKnobs {
					tlBox.origin.x = box.maxX - tlBox.size.width
					tlBox.origin.y = box.midY - (tlBox.size.height / 2)
					NSBezierPath.fill(tlBox)
				}
			}
			tlBox.origin.x = box.maxX - tlBox.size.width
			tlBox.origin.y = 0
			NSBezierPath.fill(tlBox)
		}
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
