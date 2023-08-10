import RFSupport

class NovaTools: PlaceholderProvider {
    static var supportedTypes = ["dësc"]

    static func placeholderName(for resource: Resource) -> String? {
        switch resource.typeCode {
        case "dësc":
            guard let end = resource.data.firstIndex(of: 0) else {
                return nil
            }
            let data = resource.data.prefix(upTo: end).prefix(100)
            return String(data: data, encoding: .macOSRoman)
        default:
            return nil
        }
    }
}
