import Cocoa

class PrefsController: NSWindowController, NSWindowDelegate, NSTableViewDataSource {
    @IBOutlet var favoriteTable: NSTableView!
    @IBOutlet var favoriteTypes: NSArrayController!

    override var windowNibName: NSNib.Name? {
        "PrefsWindow"
    }

    override func windowWillLoad() {
        ValueTransformer.setValueTransformer(LaunchActionTransformer(), forName: .launchActionTransformerName)
    }

    override func windowDidLoad() {
        window?.center()
    }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }

    @IBAction func add(_ sender: Any) {
        window?.makeFirstResponder(nil)
        favoriteTypes.addObject("")
        favoriteTable.editColumn(0, row: favoriteTypes.selectionIndex, with: nil, select: true)
    }

    @IBAction func remove(_ sender: Any) {
        favoriteTable.abortEditing()
        favoriteTypes.remove(atArrangedObjectIndexes: favoriteTypes.selectionIndexes)
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        (favoriteTypes.arrangedObjects as? [Any])?[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        favoriteTypes.remove(atArrangedObjectIndex: row)
        // Don't insert if invalid
        if let object = object as? String {
            // Detect duplicates
            if let idx = (favoriteTypes.arrangedObjects as? [String])?.firstIndex(of: object) {
                favoriteTypes.setSelectionIndex(idx)
            } else {
                favoriteTypes.insert(object, atArrangedObjectIndex: row)
            }
        }
    }
}

// MARK: -

struct RFDefaults {
    static let confirmChanges = "ConfirmChanges"
    static let deleteResourceWarning = "DeleteResourceWarning"
    static let launchAction = "LaunchAction"
    static let showSidebar = "ShowSidebar"
    static let thumbnailSize = "ThumbnailSize"
    static let favoriteTypes = "FavoriteTypes"

    enum LaunchAction: String, CaseIterable {
        case None
        case OpenUntitledFile
        case DisplayOpenPanel
    }

    static func register() {
        UserDefaults.standard.register(defaults: [
            confirmChanges: false,
            deleteResourceWarning: true,
            launchAction: LaunchAction.DisplayOpenPanel.rawValue,
            showSidebar: true,
            thumbnailSize: 100,
            favoriteTypes: [
                // Common types?
                "PICT",
                "snd ",
                "STR ",
                "STR#",
                "TMPL",
                // EV Nova types - these are annoying to type so keep them here as defaults
                "bööm",
                "chär",
                "cölr",
                "crön",
                "dësc",
                "düde",
                "flët",
                "gövt",
                "ïntf",
                "jünk",
                "mïsn",
                "nëbu",
                "oütf",
                "öops",
                "përs",
                "ränk",
                "rlëD",
                "röid",
                "shän",
                "shïp",
                "spïn",
                "spöb",
                "sÿst",
                "wëap",
            ]
        ])
    }
}

extension RawRepresentable where Self: CaseIterable, RawValue: Equatable {
    /// Returns the index of a raw value in the enum.
    static func index(of rawValue: RawValue) -> AllCases.Index? {
        return allCases.firstIndex { $0.rawValue == rawValue }
    }
}

// Transform launch action matrix index to string constants
class LaunchActionTransformer: ValueTransformer {
    static override func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    static override func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return RFDefaults.LaunchAction.index(of: value as! String)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return RFDefaults.LaunchAction.allCases[value as! Int].rawValue
    }
}

extension NSValueTransformerName {
    static let launchActionTransformerName = Self("LaunchActionTransformer")
}
