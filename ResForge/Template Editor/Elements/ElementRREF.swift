import Cocoa
import RFSupport

/*
 * RREF is a static reference to another resource
 * The parameters are determined from the label, in the format "Display Label='TNAM' offset Button Label"
 * If offset is prefixed with # then the referenced id will equal the offset
 * Otherwise the referenced id will equal the current resource's id plus the offset
 */
class ElementRREF: BaseElement {
    private var resType = ""
    private var id = 0
    private var buttonLabel = ""

    override func configure() throws {
        guard let metaValue,
              case let scanner = Scanner(string: metaValue),
              scanner.scanString("'") != nil,
              let typeCode = scanner.scanUpToString("'"),
              typeCode.count == 4,
              scanner.scanString("'") != nil
        else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Could not determine resource type from label.", comment: ""))
        }
        resType = typeCode
        let isRelative = scanner.scanString("#") == nil
        id = scanner.scanInt() ?? 0
        if isRelative {
            id += parentList.controller.resource.id
        }
        if scanner.isAtEnd {
            buttonLabel = "\(resType) #\(id)"
        } else {
            buttonLabel = scanner.string[scanner.currentIndex...].trimmingCharacters(in: .whitespaces)
        }
        width = 120
    }

    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 1
        frame.size.width = width - 4
        frame.size.height = 19
        let button = NSButton(frame: frame)
        button.bezelStyle = .inline
        button.title = buttonLabel
        button.font = .boldSystemFont(ofSize: 11)
        // Show add icon if resource does not exist, otherwise follow link icon
        let resource = parentList.controller.manager.findResource(type: ResourceType(resType), id: id, currentDocumentOnly: false)
        button.image = NSImage(named: resource == nil ? NSImage.touchBarAddDetailTemplateName : NSImage.followLinkFreestandingTemplateName)
        if resource == nil {
            // The add icon isn't strictly supposed to be used outside of the touch bar -
            // It works fine on macOS 11 but for appropriate sizing on 10.14 we need to set the size explicitly (default is 18x30)
            button.image?.size = NSSize(width: 14, height: 24)
        }
        button.imagePosition = .imageRight
        button.target = self
        button.action = #selector(openResource(_:))
        view.addSubview(button)
    }

    @IBAction func openResource(_ sender: Any) {
        parentList.controller.openOrCreateResource(typeCode: resType, id: id) { [weak self] resource, _ in
            // Update button image
            if let button = sender as? NSButton, resource.id == self?.id {
                button.image = NSImage(named: NSImage.followLinkFreestandingTemplateName)
            }
        }
    }
}
