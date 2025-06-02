/*
Sound Manager Interfaces
Converted from CarbonSound/Sound.h
*/

//let rate48khz: UnsignedFixed            = 0xbb800000 // 48000.00000 in fixed-point
//let rate44khz: UnsignedFixed            = 0xac440000 // 44100.00000 in fixed-point
//let rate32khz: UnsignedFixed            = 0x7d000000 // 32000.00000 in fixed-point
//let rate22050hz: UnsignedFixed          = 0x56220000 // 22050.00000 in fixed-point
//let rate22khz: UnsignedFixed            = 0x56ee8ba3 // 22254.54545 in fixed-point
//let rate16khz: UnsignedFixed            = 0x3e800000 // 16000.00000 in fixed-point
//let rate11khz: UnsignedFixed            = 0x2b7745d1 // 11127.27273 in fixed-point
//let rate11025hz: UnsignedFixed          = 0x2b110000 // 11025.00000 in fixed-point
//let rate8khz: UnsignedFixed             = 0x1f400000 //  8000.00000 in fixed-point

enum CompressionCode: Int16 {
    case notCompressed        = 0   // compression ID's
    case fixedCompression     = -1  // compression ID for fixed-sized compression
    case variableCompression  = -2  // compression ID for variable-sized compression
    case twoToOne             = 1
    case eightToThree         = 2
    case threeToOne           = 3
    case sixToOne             = 4

    static let sixToOnePacketSize: Int16 = 8
    static let threeToOnePacketSize: Int16 = 16
}

enum SoundFormat: Int16 {
    case first  = 0x0001    // general sound format
    case second = 0x0002    // special sampled sound format (HyperCard)
}

// command numbers for SndDoCommand and SndDoImmediate
// https://preterhuman.net/macstuff/techpubs/mac/Sound/Sound-66.html
enum CommandCode: UInt16 {
    case null = 0
    case quiet = 3
    case flush = 4
    case reInit = 5
    case wait = 10
    case pause = 11
    case resume = 12
    case callBack = 13
    case sync = 14
    case available = 24
    case version = 25
    case volume = 46                // sound manager 3.0 or later only
    case getVolume = 47             // sound manager 3.0 or later only
    case clockComponent = 50        // sound manager 3.2.1 or later only
    case getClockComponent = 51     // sound manager 3.2.1 or later only
    case scheduledSound = 52        // sound manager 3.3 or later only
    case linkSoundComponents = 53   // sound manager 3.3 or later only
    case sound = 80
    case buffer = 81
    case rateMultiplier = 86
    case getRateMultiplier = 87

    case offsetSound = 0x8050       // sound + dataOffsetFlag
    case offsetBuffer = 0x8051      // buffer + dataOffsetFlag

    static let dataOffsetFlag: UInt16 = 0x8000
}

struct InitOptions: OptionSet {
    let rawValue: Int32

    static let chanLeft   = Self(rawValue: 0x0002)  // left stereo channel
    static let chanRight  = Self(rawValue: 0x0003)  // right stereo channel
    static let noInterp   = Self(rawValue: 0x0004)  // no linear interpolation
    static let noDrop     = Self(rawValue: 0x0008)  // no drop-sample conversion
    static let mono       = Self(rawValue: 0x0080)  // monophonic channel
    static let stereo     = Self(rawValue: 0x00C0)  // stereo channel
    static let MACE3      = Self(rawValue: 0x0300)  // MACE 3:1
    static let MACE6      = Self(rawValue: 0x0400)  // MACE 6:1
}

// Format Types
let kSoundNotCompressed: UInt32         = 0x4E4F4E45 // 'NONE' sound is not compressed
let k8BitOffsetBinaryFormat: UInt32     = 0x72617720 // 'raw ' 8-bit offset binary
let k16BitBigEndianFormat: UInt32       = 0x74776F73 // 'twos' 16-bit big endian
let k16BitLittleEndianFormat: UInt32    = 0x736F7774 // 'sowt' 16-bit little endian

/*
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   typedefs
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

typealias UnsignedFixed = UInt32
let fixed1: UInt32 = 1<<16
func FixedToDouble(_ x: UnsignedFixed) -> Double {
    Double(x) * 1.0/Double(fixed1)
}
func DoubleToFixed(_ x: Double) -> UnsignedFixed {
    UnsignedFixed(x * Double(fixed1))
}

struct Extended80 {
    var exp: Int16
    var man: UInt64
}

struct SndCommand {
    var cmd: CommandCode
    var param1: Int16
    var param2: Int32
}

struct ModRef {
    var modNumber: UInt16
    var modInit: InitOptions

    static let sampledSynth: UInt16 = 5 // sampled sound synthesizer
}
struct SndListResource {
    var format: SoundFormat = .first
    var numModifiers: Int16
    var modifierPart: ModRef
    var numCommands: Int16 = 1
    var commandPart: [SndCommand] = []
}
// HyperCard sound resource format
struct Snd2ListResource {
    var format: SoundFormat = .second
    var refCount: Int16
    var numCommands: Int16 = 1
    var commandPart: [SndCommand] = []
}
struct SoundHeader {
    enum Encode: UInt8 {
        case standard   = 0x00      // Standard sound header encode value
        case extended   = 0xFF      // Extended sound header encode value
        case compressed = 0xFE      // Compressed sound header encode value
    }

    var samplePtr: UInt32           // if NIL then samples are in sampleArea
    var length: UInt32              // length of sound in bytes
    var sampleRate: UnsignedFixed   // sample rate for this sound
    var loopStart: UInt32           // start of looping portion
    var loopEnd: UInt32             // end of looping portion
    var encode: Encode              // header encoding
    var baseFrequency: UInt8        // baseFrequency value

    static let middleC: UInt8 = 60  // MIDI note value for middle C
}
struct CmpSoundHeader {
//    var samplePtr: UInt32              // if nil then samples are in sample area
//    var numChannels: UInt32            // number of channels i.e. mono = 1
//    var sampleRate: UnsignedFixed      // sample rate in Apples Fixed point representation
//    var loopStart: UInt32              // loopStart of sound before compression
//    var loopEnd: UInt32                // loopEnd of sound before compression
//    var encode: UInt8                  // data structure used , stdSH, extSH, or cmpSH
//    var baseFrequency: UInt8           // same meaning as regular SoundHeader
    var numFrames: UInt32              // length in frames ( packetFrames or sampleFrames )
    var AIFFSampleRate: Extended80     // IEEE sample rate
    var markerChunk: UInt32            // sync track
    var format: UInt32                 // data format type, was futureUse1
    var futureUse2: UInt32             // reserved by Apple
    var stateVars: UInt32              // pointer to State Block
    var leftOverSamples: UInt32        // used to save truncated samples between compression calls
    var compressionID: CompressionCode // 0 means no compression, non zero means compressionID
    var packetSize: UInt16             // number of bits in compressed sample packet
    var snthID: UInt16                 // resource ID of Sound Manager snth that contains NRT C/E
    var sampleSize: UInt16             // number of bits in non-compressed sample
}
struct ExtSoundHeader {
//    var samplePtr: UInt32              // if nil then samples are in sample area
//    var numChannels: UInt32            // number of channels i.e. mono = 1
//    var sampleRate: UnsignedFixed      // sample rate in Apples Fixed point representation
//    var loopStart: UInt32              // same meaning as regular SoundHeader
//    var loopEnd: UInt32                // same meaning as regular SoundHeader
//    var encode: UInt8                  // data structure used , stdSH, extSH, or cmpSH
//    var baseFrequency: UInt8           // same meaning as regular SoundHeader
    var numFrames: UInt32              // length in total number of frames
    var AIFFSampleRate: Extended80     // IEEE sample rate
    var markerChunk: UInt32            // sync track
    var instrumentChunks: UInt32       // AIFF instrument chunks
    var AESRecording: UInt32
    var sampleSize: UInt16             // number of bits in sample
    var futureUse1: UInt16             // reserved by Apple
    var futureUse2: UInt32             // reserved by Apple
    var futureUse3: UInt32             // reserved by Apple
    var futureUse4: UInt32             // reserved by Apple
}
