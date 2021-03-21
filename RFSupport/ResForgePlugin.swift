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
public protocol ResourceEditor: AbstractEditor {
    /// The list of resource types that this plugin supports.
    static var supportedTypes: [String] { get }
    
    var resource: Resource { get }
    init?(resource: Resource)
    
    // Implementers should declare these @IBAction
    func saveResource(_ sender: Any)
    func revertResource(_ sender: Any)
}

/// Template editors are additionally provided with a template resource and possibly a filter.
public protocol TemplateEditor: ResourceEditor {
    init?(resource: Resource, template: Resource, filter: TemplateFilter.Type?)
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
    static func export(_ resource: Resource, to url: URL) throws -> Bool
}

/// A placeholder provider allows custom content to be shown as a placeholder in the list view when a resource has no name.
public protocol PlaceholderProvider {
    static var supportedTypes: [String] { get }
    
    /// Return a placeholder name to show for a resource, or nil to use a default name.
    static func placeholderName(for resource: Resource) -> String?
}

/// A template filter can modify data to allow it to be interpreted by a template.
public protocol TemplateFilter {
    static var supportedTypes: [String] { get }
    /// The name of the filter that will be shown in the template editor.
    static var name: String { get }
    
    /// Filter the data when reading into a template.
    static func filter(data: Data, for resourceType: String) throws -> Data
    
    /// Reverse the filter for writing data back to the resource.
    static func unfilter(data: Data, for resourceType: String) throws -> Data
}


/// The editor manager provides utility functions and is available on resources given to editors. It should not be implemented by plugins.
public protocol ResForgeEditorManager: class {
    func open(resource: Resource, using editor: ResourceEditor.Type?, template: String?)
    func allResources(ofType: String, currentDocumentOnly: Bool) -> [Resource]
    func findResource(ofType: String, id: Int, currentDocumentOnly: Bool) -> Resource?
    func findResource(ofType: String, name: String, currentDocumentOnly: Bool) -> Resource?
    func createResource(ofType: String, id: Int, name: String)
}
