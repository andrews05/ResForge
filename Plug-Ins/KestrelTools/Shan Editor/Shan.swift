import RFSupport

struct ShanFlags: OptionSet {
    let rawValue: UInt16
    static let bankingFrames        = ShanFlags(rawValue: 0x0001)
    static let foldingFrames        = ShanFlags(rawValue: 0x0002)
    static let keyCarriedFrames     = ShanFlags(rawValue: 0x0004)
    static let animationFrames      = ShanFlags(rawValue: 0x0008)
    static let stopDisabled         = ShanFlags(rawValue: 0x0010)
    static let hideAltDisabled      = ShanFlags(rawValue: 0x0020)
    static let hideLightsDisabled   = ShanFlags(rawValue: 0x0040)
    static let unfoldsToFire        = ShanFlags(rawValue: 0x0080)
    static let pointingCorrection   = ShanFlags(rawValue: 0x0100)
}

struct Shan {
    var baseSprite: Int16 = -1
    var baseMask: Int16 = -1
    var baseSets: Int16 = 1
    var baseWidth: Int16 = 0
    var baseHeight: Int16 = 0
    var baseTransparency: Int16 = 0
    var altSprite: Int16 = -1
    var altMask: Int16 = -1
    var altSets: Int16 = 0
    var altWidth: Int16 = 0
    var altHeight: Int16 = 0
    var engineSprite: Int16 = -1
    var engineMask: Int16 = -1
    var engineWidth: Int16 = 0
    var engineHeight: Int16 = 0
    var lightSprite: Int16 = -1
    var lightMask: Int16 = -1
    var lightWidth: Int16 = 0
    var lightHeight: Int16 = 0
    var weaponSprite: Int16 = -1
    var weaponMask: Int16 = -1
    var weaponWidth: Int16 = 0
    var weaponHeight: Int16 = 0
    var flags = ShanFlags()
    var animationDelay: Int16 = 0
    var weaponDecay: Int16 = 0
    var framesPerSet: Int16 = 0
    var blinkMode: Int16 = 0
    var blinkValueA: Int16 = 0
    var blinkValueB: Int16 = 0
    var blinkValueC: Int16 = 0
    var blinkValueD: Int16 = 0
    var shieldSprite: Int16 = -1
    var shieldMask: Int16 = -1
    var shieldWidth: Int16 = 0
    var shieldHeight: Int16 = 0
    
    mutating func read(_ reader: BinaryDataReader) throws {
        baseSprite = try reader.read()
        baseMask = try reader.read()
        baseSets = try reader.read()
        baseWidth = try reader.read()
        baseHeight = try reader.read()
        baseTransparency = try reader.read()
        altSprite = try reader.read()
        altMask = try reader.read()
        altSets = try reader.read()
        altWidth = try reader.read()
        altHeight = try reader.read()
        engineSprite = try reader.read()
        engineMask = try reader.read()
        engineWidth = try reader.read()
        engineHeight = try reader.read()
        lightSprite = try reader.read()
        lightMask = try reader.read()
        lightWidth = try reader.read()
        lightHeight = try reader.read()
        weaponSprite = try reader.read()
        weaponMask = try reader.read()
        weaponWidth = try reader.read()
        weaponHeight = try reader.read()
        flags = ShanFlags(rawValue: try reader.read())
        animationDelay = try reader.read()
        weaponDecay = try reader.read()
        framesPerSet = try reader.read()
        blinkMode = try reader.read()
        blinkValueA = try reader.read()
        blinkValueB = try reader.read()
        blinkValueC = try reader.read()
        blinkValueD = try reader.read()
        shieldSprite = try reader.read()
        shieldMask = try reader.read()
        shieldWidth = try reader.read()
        shieldHeight = try reader.read()
    }
}
