import Cocoa

// RREF is a static reference to another resource based on this one's id
// The parameters are determined from the label, in the format "Display Label='TNAM' offset Button Label"
class ElementRREF: Element {
    private var resType: String!
    private var id: Int!
    private var buttonLabel: String!
    
    override func configure() throws {
        let split = self.label.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        let scanner = Scanner(string: String(split.last!))
        var resType: NSString?
        guard split.count == 2,
              scanner.scanString("'", into: nil),
              scanner.scanUpTo("'", into: &resType),
              scanner.scanString("'", into: nil),
              resType?.length == 4
        else {
            throw TemplateError.invalidStructure(self, NSLocalizedString("Could not determine resource type from label.", comment: ""))
        }
        self.resType = resType as String?
        var offset = 0
        scanner.scanInt(&offset)
        id = self.parentList.controller.resource.id + offset
        if scanner.isAtEnd {
            buttonLabel = "\(self.resType!) #\(self.id!)"
        } else {
            buttonLabel = scanner.string.dropFirst(scanner.scanLocation).trimmingCharacters(in: .whitespaces)
        }
        self.width = 120
    }
    
    override func configure(view: NSView) {
        var frame = view.frame
        frame.origin.y += 2
        frame.size.width = self.width - 4
        frame.size.height = 19
        let button = NSButton(frame: frame)
        button.bezelStyle = .inline
        button.title = buttonLabel
        button.image = NSImage(named: NSImage.followLinkFreestandingTemplateName)
        button.imagePosition = .imageRight
        button.target = self
        button.action = #selector(openResource(_:))
        view.addSubview(button)
    }
    
    @IBAction func openResource(_ sender: Any) {
        let manager = self.parentList.controller.resource.manager!
        if let resource = manager.findResource(ofType: resType, id: id, currentDocumentOnly: false) {
            manager.open(resource: resource, using: nil, template: nil)
        } else {
            manager.createResource(ofType: resType, id: id, name: "")
        }
    }
}
