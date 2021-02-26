import RFSupport

struct Shan {
    var baseID: Int16 = -1
    var baseMask: Int16 = -1
    var baseSets: Int16 = 0
    var baseWidth: Int16 = 0
    var baseHeight: Int16 = 0
    var baseTransparency: Int16 = 0
    var altID: Int16 = -1
    var altMask: Int16 = -1
    var altSets: Int16 = 0
    var altWidth: Int16 = 0
    var altHeight: Int16 = 0
    var glowID: Int16 = -1
    var glowMask: Int16 = -1
    var glowWidth: Int16 = 0
    var glowHeight: Int16 = 0
    var lightID: Int16 = -1
    var lightMask: Int16 = -1
    var lightWidth: Int16 = 0
    var lightHeight: Int16 = 0
    var weaponID: Int16 = -1
    var weaponMask: Int16 = -1
    var weaponWidth: Int16 = 0
    var weaponHeight: Int16 = 0
    var flags: UInt16 = 0
    var animationDelay: Int16 = 0
    var weaponDecay: Int16 = 0
    var framesPerSet: Int16 = 0
    var blinkMode: Int16 = 0
    var blinkValueA: Int16 = 0
    var blinkValueB: Int16 = 0
    var blinkValueC: Int16 = 0
    var shieldID: Int16 = -1
    var shieldMask: Int16 = -1
    var shieldWidth: Int16 = 0
    var shieldHeight: Int16 = 0
    
    mutating func read(_ reader: BinaryDataReader) throws {
        baseID = try reader.read()
        baseMask = try reader.read()
        baseSets = try reader.read()
        baseWidth = try reader.read()
        baseHeight = try reader.read()
        baseTransparency = try reader.read()
        altID = try reader.read()
        altMask = try reader.read()
        altSets = try reader.read()
        altWidth = try reader.read()
        altHeight = try reader.read()
        glowID = try reader.read()
        glowMask = try reader.read()
        glowWidth = try reader.read()
        glowHeight = try reader.read()
        lightID = try reader.read()
        lightMask = try reader.read()
        lightWidth = try reader.read()
        lightHeight = try reader.read()
        weaponID = try reader.read()
        weaponMask = try reader.read()
        weaponWidth = try reader.read()
        weaponHeight = try reader.read()
        flags = try reader.read()
        animationDelay = try reader.read()
        weaponDecay = try reader.read()
        framesPerSet = try reader.read()
        blinkMode = try reader.read()
        blinkValueA = try reader.read()
        blinkValueB = try reader.read()
        blinkValueC = try reader.read()
        shieldID = try reader.read()
        shieldMask = try reader.read()
        shieldWidth = try reader.read()
        shieldHeight = try reader.read()
    }
}
