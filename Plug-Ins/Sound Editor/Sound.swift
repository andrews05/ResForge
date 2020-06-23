/*
Sound Manager Interfaces
Cconverted from CarbonSound/Sound.h
*/

let rate48khz: UnsignedFixed            = 0xbb800000 /*48000.00000 in fixed-point*/
let rate44khz: UnsignedFixed            = 0xac440000 /*44100.00000 in fixed-point*/
let rate32khz: UnsignedFixed            = 0x7d000000 /*32000.00000 in fixed-point*/
let rate22050hz: UnsignedFixed          = 0x56220000 /*22050.00000 in fixed-point*/
let rate22khz: UnsignedFixed            = 0x56ee8ba3 /*22254.54545 in fixed-point*/
let rate16khz: UnsignedFixed            = 0x3e800000 /*16000.00000 in fixed-point*/
let rate11khz: UnsignedFixed            = 0x2b7745d1 /*11127.27273 in fixed-point*/
let rate11025hz: UnsignedFixed          = 0x2b110000 /*11025.00000 in fixed-point*/
let rate8khz: UnsignedFixed             = 0x1f400000 /* 8000.00000 in fixed-point*/

/*synthesizer numbers for SndNewChannel*/
let sampledSynth: UInt16                = 5     /*sampled sound synthesizer*/

let kMiddleC: UInt8                     = 60    /*MIDI note value for middle C*/

let dataOffsetFlag: UInt16              = 0x8000

let notCompressed: Int16                = 0    /*compression ID's*/
let fixedCompression: Int16             = -1   /*compression ID for fixed-sized compression*/
let variableCompression: Int16          = -2   /*compression ID for variable-sized compression*/
let twoToOne: Int16                     = 1
let eightToThree: Int16                 = 2
let threeToOne: Int16                   = 3
let sixToOne: Int16                     = 4
let sixToOnePacketSize: Int16           = 8
let threeToOnePacketSize: Int16         = 16

let firstSoundFormat: Int16             = 0x0001 /*general sound format*/
let secondSoundFormat: Int16            = 0x0002 /*special sampled sound format (HyperCard)*/

let stdSH: UInt8                        = 0x00  /*Standard sound header encode value*/
let extSH: UInt8                        = 0xFF  /*Extended sound header encode value*/
let cmpSH: UInt8                        = 0xFE  /*Compressed sound header encode value*/

/*command numbers for SndDoCommand and SndDoImmediate*/
let nullCmd: UInt16                     = 0
let quietCmd: UInt16                    = 3
let flushCmd: UInt16                    = 4
let reInitCmd: UInt16                   = 5
let waitCmd: UInt16                     = 10
let pauseCmd: UInt16                    = 11
let resumeCmd: UInt16                   = 12
let callBackCmd: UInt16                 = 13
let syncCmd: UInt16                     = 14
let availableCmd: UInt16                = 24
let versionCmd: UInt16                  = 25
let volumeCmd: UInt16                   = 46   /*sound manager 3.0 or later only*/
let getVolumeCmd: UInt16                = 47   /*sound manager 3.0 or later only*/
let clockComponentCmd: UInt16           = 50   /*sound manager 3.2.1 or later only*/
let getClockComponentCmd: UInt16        = 51   /*sound manager 3.2.1 or later only*/
let scheduledSoundCmd: UInt16           = 52   /*sound manager 3.3 or later only*/
let linkSoundComponentsCmd: UInt16      = 53   /*sound manager 3.3 or later only*/
let soundCmd: UInt16                    = 80
let bufferCmd: UInt16                   = 81
let rateMultiplierCmd: UInt16           = 86
let getRateMultiplierCmd: UInt16        = 87

let initChanLeft: Int32                 = 0x0002 /*left stereo channel*/
let initChanRight: Int32                = 0x0003 /*right stereo channel*/
let initNoInterp: Int32                 = 0x0004 /*no linear interpolation*/
let initNoDrop: Int32                   = 0x0008 /*no drop-sample conversion*/
let initMono: Int32                     = 0x0080 /*monophonic channel*/
let initStereo: Int32                   = 0x00C0 /*stereo channel*/
let initMACE3: Int32                    = 0x0300 /*MACE 3:1*/
let initMACE6: Int32                    = 0x0400 /*MACE 6:1*/

/*Format Types*/
let kSoundNotCompressed: UInt32         = 0x4E4F4E45 /*'NONE' sound is not compressed*/
let k8BitOffsetBinaryFormat: UInt32     = 0x72617720 /*'raw ' 8-bit offset binary*/
let k16BitBigEndianFormat: UInt32       = 0x74776F73 /*'twos' 16-bit big endian*/
let k16BitLittleEndianFormat: UInt32    = 0x736F7774 /*'sowt' 16-bit little endian*/

/*
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   typedefs
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

typealias UnsignedFixed = UInt32
let fixed1: UInt32 = 1<<16
func FixedToDouble(_ x: UnsignedFixed) -> Double {
    return Double(x) * 1.0/Double(fixed1)
}
func DoubleToFixed(_ x: Double) -> UnsignedFixed {
    UnsignedFixed(x * Double(fixed1))
}

struct extended80 {
    var exp: Int16
    var man: UInt64
}

struct SndCommand {
    var cmd: UInt16
    var param1: Int16
    var param2: Int32
}

struct ModRef {
    var modNumber: UInt16
    var modInit: Int32
}
struct SndListResource {
    var format: Int16
    var numModifiers: Int16
    var modifierPart: ModRef
    var numCommands: Int16
    var commandPart: SndCommand
}
/*HyperCard sound resource format*/
struct Snd2ListResource {
    var format: Int16
    var refCount: Int16
    var numCommands: Int16
    var commandPart: SndCommand
}
struct SoundHeader {
    var samplePtr: UInt32              /*if NIL then samples are in sampleArea*/
    var length: UInt32                 /*length of sound in bytes*/
    var sampleRate: UnsignedFixed      /*sample rate for this sound*/
    var loopStart: UInt32              /*start of looping portion*/
    var loopEnd: UInt32                /*end of looping portion*/
    var encode: UInt8                  /*header encoding*/
    var baseFrequency: UInt8           /*baseFrequency value*/
}
struct CmpSoundHeader {
//    var samplePtr: UInt32              /*if nil then samples are in sample area*/
//    var numChannels: UInt32            /*number of channels i.e. mono = 1*/
//    var sampleRate: UnsignedFixed      /*sample rate in Apples Fixed point representation*/
//    var loopStart: UInt32              /*loopStart of sound before compression*/
//    var loopEnd: UInt32                /*loopEnd of sound before compression*/
//    var encode: UInt8                  /*data structure used , stdSH, extSH, or cmpSH*/
//    var baseFrequency: UInt8           /*same meaning as regular SoundHeader*/
    var numFrames: UInt32              /*length in frames ( packetFrames or sampleFrames )*/
    var AIFFSampleRate: extended80     /*IEEE sample rate*/
    var markerChunk: UInt32            /*sync track*/
    var format: OSType                 /*data format type, was futureUse1*/
    var futureUse2: UInt32             /*reserved by Apple*/
    var stateVars: UInt32              /*pointer to State Block*/
    var leftOverSamples: UInt32        /*used to save truncated samples between compression calls*/
    var compressionID: Int16           /*0 means no compression, non zero means compressionID*/
    var packetSize: UInt16             /*number of bits in compressed sample packet*/
    var snthID: UInt16                 /*resource ID of Sound Manager snth that contains NRT C/E*/
    var sampleSize: UInt16             /*number of bits in non-compressed sample*/
}
struct ExtSoundHeader {
//    var samplePtr: UInt32              /*if nil then samples are in sample area*/
//    var numChannels: UInt32            /*number of channels i.e. mono = 1*/
//    var sampleRate: UnsignedFixed      /*sample rate in Apples Fixed point representation*/
//    var loopStart: UInt32              /*same meaning as regular SoundHeader*/
//    var loopEnd: UInt32                /*same meaning as regular SoundHeader*/
//    var encode: UInt8                  /*data structure used , stdSH, extSH, or cmpSH*/
//    var baseFrequency: UInt8           /*same meaning as regular SoundHeader*/
    var numFrames: UInt32              /*length in total number of frames*/
    var AIFFSampleRate: extended80     /*IEEE sample rate*/
    var markerChunk: UInt32            /*sync track*/
    var instrumentChunks: UInt32       /*AIFF instrument chunks*/
    var AESRecording: UInt32
    var sampleSize: UInt16             /*number of bits in sample*/
    var futureUse1: UInt16             /*reserved by Apple*/
    var futureUse2: UInt32             /*reserved by Apple*/
    var futureUse3: UInt32             /*reserved by Apple*/
    var futureUse4: UInt32             /*reserved by Apple*/
}
