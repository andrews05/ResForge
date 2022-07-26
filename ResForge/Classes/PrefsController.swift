import Cocoa

class PrefsController: NSWindowController {
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

    @IBAction func add(_ sender: Any) {
        favoriteTypes.addObject("xxxx")
    }

    @IBAction func remove(_ sender: Any) {
        favoriteTypes.remove(contentsOf: favoriteTypes.selectedObjects)
    }
}

// MARK: -

struct RFDefaults {
    static let confirmChanges = "ConfirmChanges"
    static let deleteResourceWarning = "DeleteResourceWarning"
    static let launchAction = "LaunchAction"
    static let showSidebar = "ShowSidebar"
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
            favoriteTypes: [
                "PICT",
                "snd ",
                "STR ",
                "STR#",
                "TMPL",
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
