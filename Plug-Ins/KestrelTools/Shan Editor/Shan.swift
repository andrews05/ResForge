import RFSupport

struct Shan {
    var base: UInt16
    var baseSets: UInt16
    var baseTransparency: UInt16
    var alt: UInt16
    var altSets: UInt16
    var glow: UInt16
    var lights: UInt16
    var weap: UInt16
    var shields: UInt16
    
    init(_ data: Data) throws {
        let reader = BinaryDataReader(data)
        base = try reader.read()
        try reader.advance(2)
        baseSets = try reader.read()
        try reader.advance(4)
        baseTransparency = try reader.read()
        alt = try reader.read()
        try reader.advance(2)
        altSets = try reader.read()
        try reader.advance(4)
        glow = try reader.read()
        try reader.advance(6)
        lights = try reader.read()
        try reader.advance(6)
        weap = try reader.read()
        try reader.advance(6)
        shields = try reader.read()
        try reader.advance(6)
    }
}
