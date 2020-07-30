import Foundation

let kConfirmChanges = "ConfirmChanges"
let kDeleteResourceWarning =  "DeleteResourceWarning"
let kLaunchAction = "LaunchAction"
let kOpenUntitledFile = "OpenUntitledFile"
let kDisplayOpenPanel = "DisplayOpenPanel"
let kNoLaunchOption = "None"

// Transform launch action matrix index to string constants
class LaunchActionTransformer: ValueTransformer {
    private static let launchActions: [String] = [
        kNoLaunchOption,
        kOpenUntitledFile,
        kDisplayOpenPanel
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
    static let launchActionTransformerName = Self(rawValue: "LaunchActionTransformer")
}
