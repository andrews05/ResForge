import Cocoa
import RFSupport


class DialogEditorWindowController: AbstractEditor, ResourceEditor {
	static let supportedTypes = [
		"DITL",
	]
	
	let resource: Resource
	private let manager: RFEditorManager
	@IBOutlet var scrollView: NSScrollView!
	@IBOutlet var typePopup: NSPopUpButton!
	@IBOutlet var resourceIDField: NSTextField!
	@IBOutlet var titleContentsField: NSTextField!
	@IBOutlet var tabView: NSTabView!
	@IBOutlet weak var enabledCheckbox: NSButton!
	@IBOutlet var helpResourceIDField: NSTextField!
	@IBOutlet var helpTypePopup: NSPopUpButton!
	@IBOutlet var helpItemField: NSTextField!
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
		NotificationCenter.default.addObserver(self, selector: #selector(itemDoubleClicked(_:)), name: DITLDocumentView.itemDoubleClickedNotification, object: self.scrollView.documentView)
		NotificationCenter.default.addObserver(self, selector: #selector(itemFrameDidChange(_:)), name: DITLDocumentView.itemFrameDidChangeNotification, object: self.scrollView.documentView)
		NotificationCenter.default.addObserver(self, selector: #selector(selectedItemDidChange(_:)), name: DITLDocumentView.selectionDidChangeNotification, object: self.scrollView.documentView)
		NotificationCenter.default.addObserver(self, selector: #selector(selectedItemWillChange(_:)), name: DITLDocumentView.selectionWillChangeNotification, object: self.scrollView.documentView)
		self.loadItems()
		self.updateView()
	}
	
	@objc func itemDoubleClicked(_ notification: Notification) {
		// If we had a hideable inspector, this is where we'd show it.
	}
	
	@objc func itemFrameDidChange(_ notification: Notification) {
		self.setDocumentEdited(true)
	}
	
	func reflectSelectedItem() {
		for item in items {
			if item.itemView.selected {
				typePopup.selectItem(withTag: Int(item.itemType.rawValue))
				typePopup.isEnabled = true
				enabledCheckbox.state = item.enabled ? .on : .off
				enabledCheckbox.isEnabled = true

				switch item.itemType {
				case .userItem, .unknown:
					tabView.selectTabViewItem(at: 3)
				case .helpItem:
					tabView.selectTabViewItem(at: 2)
					helpResourceIDField.integerValue = item.resourceID
					helpTypePopup.selectItem(withTag: Int(item.helpItemType.rawValue))
					if item.helpItemType == .HMScanAppendhdlg {
						helpItemField.integerValue = Int(item.itemNumber)
						helpItemField.isEnabled = true
					} else {
						helpItemField.isEnabled = false
					}
				case .button, .checkBox, .radioButton, .staticText, .editText:
					tabView.selectTabViewItem(at: 0)
					titleContentsField.stringValue = item.itemView.title
				case .control, .icon, .picture:
					tabView.selectTabViewItem(at: 1)
					resourceIDField.integerValue = item.resourceID
				}
				return
			}
		}
		tabView.selectTabViewItem(at: 3)
		enabledCheckbox.isEnabled = false
		typePopup.isEnabled = false
	}
	
	@objc func selectedItemWillChange(_ notification: Notification) {
		window?.makeFirstResponder(scrollView.documentView)
	}
	
	@objc func selectedItemDidChange(_ notification: Notification) {
		reflectSelectedItem()
	}
	
	/// Reload the views representing our ``items`` list.
	private func updateView() {
		for view in self.scrollView.documentView?.subviews ?? [] {
			view.removeFromSuperview()
		}
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
		if #available(macOS 14, *) { // If built w. macOS 14+ SDK, this defaults to false.
			self.scrollView.documentView?.clipsToBounds = true
		}
	}
	
	private func itemsFromData(_ data: Data) throws -> [DITLItem] {
		let reader = BinaryDataReader(data)
		let itemCountMinusOne: Int16 = try reader.read()
		var itemCount: Int = Int(itemCountMinusOne) + 1
		var newItems = [DITLItem]()
		
		while itemCount > 0 {
			let item = try DITLItem.read(reader, manager: manager)
			newItems.append(item)

			itemCount -= 1
		}
		return newItems
	}
	
	/// Parse the resource into our ``items`` list.
	private func loadItems() {
		if resource.data.isEmpty {
			createEmptyResource()
		}
		do {
			items = try itemsFromData(resource.data)
		} catch {
			items = []
			self.window?.presentError(error)
		}
	}
	
	/// Create a valid but empty DITL resource. Used when we are opened for an empty resource.
	private func createEmptyResource() {
		let writer = BinaryDataWriter()
		let numItems = Int16(-1)
		writer.write(numItems)
		resource.data = writer.data
		
		self.setDocumentEdited(true)
	}
	
	private func currentResourceStateAsData() throws -> Data {
		let writer = BinaryDataWriter()

		let numItems: Int16 = Int16(items.count) - 1
		writer.write(numItems)
		for item in items {
			try item.write(to: writer)
		}
		return writer.data
	}
	
	/// Write the current state of the ``items`` list back to the resource.
	@IBAction func saveResource(_ sender: Any) {
		do {
			resource.data = try currentResourceStateAsData()
		} catch {
			self.window?.presentError(error)
		}
		
		self.setDocumentEdited(false)
	}
	
	/// Revert the resource to its on-disk state.
	@IBAction func revertResource(_ sender: Any) {
		self.loadItems()
		self.updateView()
		
		self.setDocumentEdited(false)
	}
	

	func windowDidBecomeKey(_ notification: Notification) {
		let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
		createItem?.title = NSLocalizedString("Create New Item", comment: "")
	}
	
	func windowDidResignKey(_ notification: Notification) {
		let createItem = NSApp.mainMenu?.item(withTag: 3)?.submenu?.item(withTag: 0)
		createItem?.title = NSLocalizedString("Create New Resource…", comment: "")
	}
	
	@IBAction func deselectAll(_ sender: Any?) {
		NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: scrollView.documentView)
		for itemView in scrollView.documentView?.subviews ?? [] {
			if let itemView = itemView as? DITLItemView,
			   itemView.selected {
				itemView.selected = false
				itemView.needsDisplay = true
			}
		}
		NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: scrollView.documentView)
	}
	
	override func selectAll(_ sender: Any?) {
		NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: scrollView.documentView)
		for itemView in scrollView.documentView?.subviews ?? [] {
			if let itemView = itemView as? DITLItemView,
			   !itemView.selected {
				itemView.selected = true
				itemView.needsDisplay = true
			}
		}
		NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: scrollView.documentView)
	}
	
	@IBAction func createNewItem(_ sender: Any?) {
		deselectAll(nil)
		let view = DITLItemView(frame: NSRect(origin: NSPoint(x: 10, y: 10), size: NSSize(width: 80, height: 20)), title: "Button", type: .button, enabled: true, resourceID: 0, manager: manager)
		NotificationCenter.default.post(name: DITLDocumentView.selectionWillChangeNotification, object: scrollView.documentView)
		view.selected = true
		let newItem = DITLItem(itemView: view, enabled: true, itemType: .button, resourceID: 0, helpItemType: .unknown, itemNumber: 0)
		items.append(newItem)
		self.scrollView.documentView?.addSubview(view)
		NotificationCenter.default.post(name: DITLDocumentView.selectionDidChangeNotification, object: scrollView.documentView)
		self.setDocumentEdited(true)
	}
	
	@IBAction func delete(_ sender: Any?) {
		do {
			let oldData = try currentResourceStateAsData()
		
			var didChange = false
			for itemIndex in (0 ..< items.count).reversed() {
				let itemView = items[itemIndex].itemView
				if itemView.selected {
					itemView.removeFromSuperview()
					items.remove(at: itemIndex)
					didChange = true
				}
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Delete Item", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	private func undoRedoResourceData(_ data: Data) {
		do {
			let oldData = try currentResourceStateAsData()
			self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
			
			for item in items {
				item.itemView.removeFromSuperview()
			}
			
			do {
				items = try self.itemsFromData(data)
				self.updateView()
				self.reflectSelectedItem()
				
				self.setDocumentEdited(true)
			} catch {
				self.window?.presentError(error)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	@IBAction func typePopupSelectionDidChange(_ sender: NSPopUpButton) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newType = DITLItem.DITLItemType(rawValue: UInt8(sender.selectedTag())) ?? .unknown
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					items[itemIndex].itemType = newType
					itemView.type = newType
					itemView.needsDisplay = true
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Type", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	@IBAction func resourceIDFieldChanged(_ sender: Any) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newID = resourceIDField.integerValue
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					items[itemIndex].resourceID = newID
					itemView.resourceID = newID
					itemView.needsDisplay = true
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Resource ID", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	@IBAction func helpResourceIDFieldChanged(_ sender: Any) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newID = helpResourceIDField.integerValue
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					items[itemIndex].resourceID = newID
					itemView.resourceID = newID
					itemView.needsDisplay = true
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Resource ID", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	@IBAction func helpTypePopupSelectionDidChange(_ sender: NSPopUpButton) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newType = DITLItem.DITLHelpItemType(rawValue: UInt16(sender.selectedTag())) ?? .unknown
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					items[itemIndex].helpItemType = newType
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Help Type", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	@IBAction func helpItemFieldChanged(_ sender: Any) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newID = Int16(helpItemField.integerValue)
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					items[itemIndex].itemNumber = newID
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Help Item Index", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}

	@IBAction func enabledCheckBoxChanged(_ sender: Any) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newState = enabledCheckbox.state == .on
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					items[itemIndex].enabled = newState
					itemView.enabled = newState
					itemView.needsDisplay = true
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Enable State", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
	@IBAction func titleContentsFieldChanged(_ sender: Any) {
		do {
			let oldData = try currentResourceStateAsData()
			
			var didChange = false
			var itemIndex = 0
			let newTitle = titleContentsField.stringValue
			for item in items {
				let itemView = item.itemView
				if itemView.selected {
					itemView.title = newTitle
					itemView.needsDisplay = true
					didChange = true
				}
				itemIndex += 1
			}
			reflectSelectedItem()
			if didChange {
				self.window?.contentView?.undoManager?.beginUndoGrouping()
				self.window?.contentView?.undoManager?.setActionName(NSLocalizedString("Change Item Text", comment: ""))
				self.window?.contentView?.undoManager?.registerUndo(withTarget: self, handler: { $0.undoRedoResourceData(oldData) })
				self.window?.contentView?.undoManager?.endUndoGrouping()
				
				self.setDocumentEdited(true)
			}
		} catch {
			self.window?.presentError(error)
		}
	}
	
}
