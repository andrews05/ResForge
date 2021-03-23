import Foundation

struct RFDefaults {
    static let confirmChanges = "ConfirmChanges"
    static let deleteResourceWarning =  "DeleteResourceWarning"
    static let launchAction = "LaunchAction"
    static let showSidebar = "ShowSidebar"
    struct LaunchActions {
        static let openUntitledFile = "OpenUntitledFile"
        static let displayOpenPanel = "DisplayOpenPanel"
        static let none = "None"
    }
}

// Transform launch action matrix index to string constants
class LaunchActionTransformer: ValueTransformer {
    private static let launchActions: [String] = [
        RFDefaults.LaunchActions.none,
        RFDefaults.LaunchActions.openUntitledFile,
        RFDefaults.LaunchActions.displayOpenPanel
    ]
        
    static override func transformedValueClass() -> AnyClass {
        return NSNumber.self
    }
    
    static override func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        return Self.launchActions.firstIndex(of: value as! String)
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return Self.launchActions[value as! Int]
    }
}

extension NSValueTransformerName {
    static let launchActionTransformerName = Self("LaunchActionTransformer")
}
