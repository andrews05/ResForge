import AppKit

public protocol RFPlugin: AnyObject {
    /// The bundle containing resources for the plugin, usually `Bundle.module`.
    static var bundle: Bundle { get }
    /// Register the plugin and perform any necessary initialisation.
    static func register()
}

/// An editor provides a window for editing or viewing resources of the supported types.
public protocol ResourceEditor: AbstractEditor, RFPlugin {
    /// The list of resource types that this editor supports.
    static var supportedTypes: [String] { get }

    /// The resource that the editor is editing.
    var resource: Resource { get }

    /// The title of the editor's window. Default implementation provided.
    var windowTitle: String { get }

    /// The title of the "Create" menu item, if the editor implements the `createNewItem()` function.
    var createMenuTitle: String? { get }

    /// Initialise the editor with the resource to be edited and the editor manager.
    /// May return nil if the editor is unable to edit the resource.
    init?(resource: Resource, manager: RFEditorManager)

    // Implementers should declare these @IBAction (or @obj)
    func saveResource(_ sender: Any)
    func revertResource(_ sender: Any)
}
public extension ResourceEditor  {
    var windowTitle: String { resource.defaultWindowTitle }
    var createMenuTitle: String? { nil }

    static func register() {
        PluginRegistry.registerClass(self)
    }
}

/// A preview provider allows the document to display a grid view for a supported resource type.
public protocol PreviewProvider {
    static var supportedTypes: [String] { get }

    /// Return the max thumbnail size for grid view.
    static func maxThumbnailSize(for resourceType: String) -> Int?

    /// Return an image representing the resource for use in grid view.
    static func image(for resource: Resource) -> NSImage?
}
public extension PreviewProvider {
    static func maxThumbnailSize(for resourceType: String) -> Int? {
        return nil
    }
}

/// An export provider allows control over the file written for a resource when exported.
public protocol ExportProvider {
    static var supportedTypes: [String] { get }

    /// Return the filename extension for the resource type.
    static func filenameExtension(for resourceType: String) -> String

    /// Write a file representing the resource to the given url.
    static func export(_ resource: Resource, to url: URL) throws
}

/// A placeholder provider allows custom content to be shown as a placeholder in the list view when a resource has no name.
public protocol PlaceholderProvider {
    static var supportedTypes: [String] { get }

    /// Return a placeholder name to show for a resource, or nil to use a default name.
    static func placeholderName(for resource: Resource) -> String?
}

/// A type icon provider allows specific icons to be shown in the type list.
public protocol TypeIconProvider {
    /// Mapping of type codes to icon characters or symbol names.
    static var typeIcons: [String: String] { get }
}

/// A template filter can modify data to allow it to be interpreted by a template.
public protocol TemplateFilter {
    static var supportedTypes: [String] { get }
    /// The name of the filter that will be shown in the template editor.
    static var name: String { get }

    /// Filter the data when reading into a template.
    static func filter(data: Data, for resourceType: String) throws -> Data

    /// Reverse the filter for writing data back to the resource.
    static func unfilter(data: Data, for resourceType: String) -> Data
}

/// The editor manager provides utility functions and is provided to editors on init. It should not be implemented by plugins.
public protocol RFEditorManager: AnyObject {
    var document: NSDocument? { get }
    func open(resource: Resource)
    func open(resource: Resource, using editor: ResourceEditor.Type)
    func allResources(ofType: ResourceType, currentDocumentOnly: Bool) -> [Resource]
    func findResource(type: ResourceType, id: Int, currentDocumentOnly: Bool) -> Resource?
    func findResource(type: ResourceType, name: String, currentDocumentOnly: Bool) -> Resource?
    /// Open the resource creation modal with the given properties. Callback will be called if a resource was created with the same type that was requested.
    func createResource(type: ResourceType, id: Int?, name: String, callback: ((Resource) -> Void)?)
}
// Extension facilitates optional arguments for protocol functions.
public extension RFEditorManager {
    func findResource(type: ResourceType, id: Int, currentDocumentOnly: Bool = false) -> Resource? {
        findResource(type: type, id: id, currentDocumentOnly: currentDocumentOnly)
    }
    func createResource(type: ResourceType, id: Int? = nil, name: String = "", callback: ((Resource) -> Void)? = nil) {
        createResource(type: type, id: id, name: name, callback: callback)
    }
}
