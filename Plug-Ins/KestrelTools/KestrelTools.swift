import RFSupport

class KestrelTools: PlaceholderProvider {
    static var supportedTypes = ["dësc"]
    
    static func placeholderName(for resource: Resource) -> String? {
        switch resource.type {
        case "dësc":
            let end = min(100, resource.data.firstIndex(of: 0) ?? 0)
            if end == 0 {
                return nil
            }
            return String(data: resource.data[0..<end], encoding: .macOSRoman)
        default:
            return nil
        }
    }
}
