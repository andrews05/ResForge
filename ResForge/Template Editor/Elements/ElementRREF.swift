import Cocoa
import RFSupport

/*
 * RREF is a static reference to another resource
 * The parameters are determined from the label, in the format "Display Label='TNAM' offset Button Label"
 * If offset is prefixed with # then the referenced id will equal the offset
 * Otherwise the referenced id will equal the current resource's id plus the offset
 */
class ElementRREF: Element {
    private var resType: String!
    private var id = 0
    private var buttonLabel: String!
    
    override func configure() throws {
        var resType: NSString?
        guard let metaValue = metaValue,
              case let scanner = Scanner(string: metaValue),
              scanner.scanString("'", into: nil),
              scanner.scanUpTo("'", into: &resType),
              scanner.scanString("'", into: nil),
              resType?.length == 4
        else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Could not determine resource type from label.", comment: ""))
        }
        self.resType = resType as String?
        if scanner.scanString("#", into: nil) {
            scanner.scanInt(&id)
        } else {
            scanner.scanInt(&id)
            id += self.parentList.controller.resource.id
        }
        if scanner.isAtEnd {
            buttonLabel = "\(self.resType!) #\(self.id)"
        } else {
            buttonLabel = scanner.string.dropFirst(scanner.scanLocation).trimmingCharacters(in: .whitespaces)
        }
        self.width = 120
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 1
        frame.size.width = self.width - 4
        frame.size.height = 19
        let button = NSButton(frame: frame)
        button.bezelStyle = .inline
        button.title = buttonLabel
        button.font = .boldSystemFont(ofSize: 11)
        button.image = NSImage(named: NSImage.followLinkFreestandingTemplateName)
        button.imagePosition = .imageRight
        button.target = self
        button.action = #selector(openResource(_:))
        view.addSubview(button)
    }
    
    @IBAction func openResource(_ sender: Any) {
        self.parentList.controller.openOrCreateResource(typeCode: resType, id: id)
    }
}
