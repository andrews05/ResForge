import Cocoa

public extension FourCharCode {
    var stringValue: String {
        return UTCreateStringForOSType(self).takeRetainedValue() as String
    }
    init(_ string: String) {
        self = UTGetOSTypeFromString(string as CFString)
    }
}

/// An editor provides a window for editing or viewing resources of the supported types.
public protocol ResourceEditor: NSWindowController {
    /// The list of resource types that this plugin supports.
    static var supportedTypes: [String] { get }
    
    var resource: Resource { get }
    init?(resource: Resource)
    
    func saveResource(_ sender: Any)
    func revertResource(_ sender: Any)
}

/// A template editor is a special type of editor that it also given a template resource on initialization.
public protocol TemplateEditor: ResourceEditor {
    init?(resource: Resource, template: Resource)
}

/// A preview provider allows the document to display a grid view for a supported resource type.
public protocol PreviewProvider {
    static var supportedTypes: [String] { get }
    
    /// Return the preferred preview size for grid view.
    static func previewSize(for resourceType: String) -> Int
    
    /// Return an image representing the resource for use in grid view.
    static func image(for resource: Resource) -> NSImage?
}

/// An export provider allows control over the file written for a resource when exported.
public protocol ExportProvider {
    static var supportedTypes: [String] { get }
    
    /// Return the filename extension for the resource type.
    static func filenameExtension(for resourceType: String) -> String
    
    /// Write a file representing the resource to the given url. If false is returned, the resource's data will be written directly.
    static func export(_ resource: Resource, to url: URL) -> Bool
}

/// A placeholder provider allows custom content to be shown as a placeholder in the list view when a resource has no name.
public protocol PlaceholderProvider {
    static var supportedTypes: [String] { get }
    
    /// Return a placeholder name to show for a resource, or nil to use a default name.
    static func placeholderName(for resource: Resource) -> String?
}


/// The editor manager provides utility functions and is available on resources given to editors. It should not be implemented by plugins.
public protocol ResForgeEditorManager: class {
    func open(resource: Resource, using editor: ResourceEditor.Type?, template: String?)
    func allResources(ofType: String, currentDocumentOnly: Bool) -> [Resource]
    func findResource(ofType: String, id: Int, currentDocumentOnly: Bool) -> Resource?
    func findResource(ofType: String, name: String, currentDocumentOnly: Bool) -> Resource?
    func createResource(ofType: String, id: Int, name: String)
}