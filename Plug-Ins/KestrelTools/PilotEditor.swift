import Cocoa
import RFSupport

// The pilot editor acts as a middle-man for the template editor. (The implementation is a bit of a hack for now).
class PilotEditor: AbstractEditor, ResourceEditor {
    static var supportedTypes = ["NpïL"]
    
    var resource: Resource
    private var templateEditor: TemplateEditor!
    override var window: NSWindow? {
        get { templateEditor.window }
        set { }
    }
    
    required init?(resource: Resource) {
        guard let template = resource.manager.findResource(ofType: "TMPL", name: resource.type, currentDocumentOnly: false) else {
            return nil
        }
        self.resource = resource
        super.init(window: nil)
        // Create a new resource with the decrypted data for the template editor to work with.
        let newResource = Resource(type: resource.type,
                                   id: resource.id,
                                   name: resource.name,
                                   attributes: resource.attributes.rawValue,
                                   data: self.crypt(resource.data))
        newResource.document = resource.document
        templateEditor = PluginRegistry.templateEditor.init(resource: newResource, template: template)
        guard templateEditor != nil else {
            return nil
        }
        // We need to be the window controller so the editor manager can release us when the window closes
        templateEditor.window?.windowController = self
        NotificationCenter.default.addObserver(self, selector: #selector(dataDidChange(_:)), name: .ResourceDataDidChange, object: newResource)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func close() {
        super.close()
        templateEditor.close()
    }
    
    @IBAction func saveResource(_ sender: Any) {
        templateEditor.saveResource(sender)
    }
    
    @IBAction func revertResource(_ sender: Any) {
        templateEditor.revertResource(sender)
    }
    
    @objc private func dataDidChange(_ notifcation: Notification) {
        // Re-encrypt the data back into the original resource
        if let r = notifcation.object as? Resource {
            resource.data = self.crypt(r.data)
        }
    }
    
    private func crypt(_ data: Data) -> Data {
        var magic: UInt32 = 0xB36A210F
        // Work through 4 bytes at a time by converting to [UInt32] and back
        var newData = data.withUnsafeBytes({ Array($0.bindMemory(to: UInt32.self)) }).map({ i -> UInt32 in
            let j = i ^ magic.bigEndian
            magic &+= 0xDEADBEEF
            magic ^= 0xDEADBEEF
            return j
        }).withUnsafeBufferPointer({ Data(buffer: $0) })
        // Work through remaining bytes
        for i in data[newData.count...] {
            newData.append(i ^ UInt8(magic >> 24))
            magic <<= 8
        }
        return newData
    }
}
