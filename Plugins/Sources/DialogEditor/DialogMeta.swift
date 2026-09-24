/// Additional info about a dialog that is not stored in either the DITL or DLOG resources.
public struct DialogMeta {
    let itemNames: [String?]
    let backgroundPictID: Int?

    public init(itemNames: [String?], backgroundPictID: Int? = nil) {
        self.backgroundPictID = backgroundPictID
        self.itemNames = itemNames
    }
}

extension DialogMeta {
    static var idMap: [Int: Self] = [:]

    /// Register a collection of DITL IDs mapped to DialogMetas.
    public static func register(_ metadata: [Int: Self]) {
        self.idMap.merge(metadata) { _, new in new }
    }
}
