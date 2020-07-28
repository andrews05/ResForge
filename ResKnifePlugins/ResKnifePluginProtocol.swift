import Cocoa

public extension FourCharCode {
    var stringValue: String {
        return UTCreateStringForOSType(self).takeRetainedValue() as String
    }
    init(_ string: String) {
        self = UTGetOSTypeFromString(string as CFString)
    }
}

@objc public protocol ResKnifePlugin {
    @objc var resource: ResKnifeResource { get }
    @objc init(resource: ResKnifeResource)
    
    @objc optional func saveResource(_ sender: Any)
    @objc optional func revertResource(_ sender: Any)
    
    @objc optional static func export(_ resource: ResKnifeResource, to url: URL)
    @objc optional static func filenameExtension(for resourceType: String) -> String
    @objc optional static func icon(for resourceType: String) -> NSImage?
    @objc optional static func image(for resource: ResKnifeResource) -> NSImage?
}

@objc public protocol ResKnifeTemplatePlugin: ResKnifePlugin {
    @objc init(resource: ResKnifeResource, template: ResKnifeResource)
}

@objc public protocol ResKnifePluginManager {
    @objc func allResources(ofType: String, currentDocumentOnly: Bool) -> [ResKnifeResource]
    @objc func findResource(ofType: String, id: Int, currentDocumentOnly: Bool) -> ResKnifeResource?
    @objc func findResource(ofType: String, name: String, currentDocumentOnly: Bool) -> ResKnifeResource?
}
