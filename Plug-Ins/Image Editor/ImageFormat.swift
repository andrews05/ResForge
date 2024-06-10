
enum ImageFormat: CustomStringConvertible {
    case unknown
    case monochrome
    case color(Int)
    case quickTime(UInt32, Int)

    var description: String {
        switch self {
        case .unknown:
            return ""
        case .monochrome:
            return "Monochrome"
        case let .color(depth):
            if depth <= 8 {
                return "\(depth)-bit Indexed"
            }
            return "\(depth)-bit RGB"
        case let .quickTime(compressor, depth):
            let fourCC = compressor.fourCharString.trimmingCharacters(in: .whitespaces).uppercased()
            return "\(depth)-bit \(fourCC)"
        }
    }
}

enum ImageReaderError: Error {
    case invalid
    case unsupported
}
