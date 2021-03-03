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
    var gunX: [Int16] = [0,0,0,0]
    var gunY: [Int16] = [0,0,0,0]
    var turretX: [Int16] = [0,0,0,0]
    var turretY: [Int16] = [0,0,0,0]
    var guidedX: [Int16] = [0,0,0,0]
    var guidedY: [Int16] = [0,0,0,0]
    var beamX: [Int16] = [0,0,0,0]
    var beamY: [Int16] = [0,0,0,0]
    var upCompressX: Int16 = 0
    var upCompressY: Int16 = 0
    var downCompressX: Int16 = 0
    var downCompressY: Int16 = 0
    var gunZ: [Int16] = [0,0,0,0]
    var turretZ: [Int16] = [0,0,0,0]
    var guidedZ: [Int16] = [0,0,0,0]
    var beamZ: [Int16] = [0,0,0,0]
    var unused1: UInt64 = 0
    var unused2: UInt64 = 0
    
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
        for i in 0..<gunX.count {
            gunX[i] = try reader.read()
        }
        for i in 0..<gunY.count {
            gunY[i] = try reader.read()
        }
        for i in 0..<turretX.count {
            turretX[i] = try reader.read()
        }
        for i in 0..<turretY.count {
            turretY[i] = try reader.read()
        }
        for i in 0..<guidedX.count {
            guidedX[i] = try reader.read()
        }
        for i in 0..<guidedY.count {
            guidedY[i] = try reader.read()
        }
        for i in 0..<beamX.count {
            beamX[i] = try reader.read()
        }
        for i in 0..<beamY.count {
            beamY[i] = try reader.read()
        }
        upCompressX = try reader.read()
        upCompressY = try reader.read()
        downCompressX = try reader.read()
        downCompressY = try reader.read()
        for i in 0..<gunZ.count {
            gunZ[i] = try reader.read()
        }
        for i in 0..<turretZ.count {
            turretZ[i] = try reader.read()
        }
        for i in 0..<guidedZ.count {
            guidedZ[i] = try reader.read()
        }
        for i in 0..<beamZ.count {
            beamZ[i] = try reader.read()
        }
    }
    
    struct Flags: OptionSet {
        let rawValue: UInt16
        static let bankingFrames        = Self(rawValue: 0x0001)
        static let foldingFrames        = Self(rawValue: 0x0002)
        static let keyCarriedFrames     = Self(rawValue: 0x0004)
        static let animationFrames      = Self(rawValue: 0x0008)
        static let stopDisabled         = Self(rawValue: 0x0010)
        static let hideAltDisabled      = Self(rawValue: 0x0020)
        static let hideLightsDisabled   = Self(rawValue: 0x0040)
        static let unfoldsToFire        = Self(rawValue: 0x0080)
        static let pointingCorrection   = Self(rawValue: 0x0100)
    }
    
    struct ExitPoint {
        var x: Int16 = 0
        var y: Int16 = 0
        var z: Int16 = 0
    }
}
