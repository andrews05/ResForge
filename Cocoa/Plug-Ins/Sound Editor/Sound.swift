enum SampleRate : UInt32 {
    case rate48khz                      = 0xbb800000 /*48000.00000 in fixed-point*/
    case rate44khz                      = 0xac440000 /*44100.00000 in fixed-point*/
    case rate32khz                      = 0x7d000000 /*32000.00000 in fixed-point*/
    case rate22050hz                    = 0x56220000 /*22050.00000 in fixed-point*/
    case rate22khz                      = 0x56ee8ba3 /*22254.54545 in fixed-point*/
    case rate16khz                      = 0x3e800000 /*16000.00000 in fixed-point*/
    case rate11khz                      = 0x2b7745d1 /*11127.27273 in fixed-point*/
    case rate11025hz                    = 0x2b110000 /*11025.00000 in fixed-point*/
    case rate8khz                       = 0x1f400000 /* 8000.00000 in fixed-point*/
}

/*synthesizer numbers for SndNewChannel*/
let sampledSynth                        = 5     /*sampled sound synthesizer*/

let kMiddleC                            = 60    /*MIDI note value for middle C*/

let dataOffsetFlag                      = 0x8000

enum CompressionID : Int16 {
    case notCompressed                  = 0    /*compression ID's*/
    case fixedCompression               = -1   /*compression ID for fixed-sized compression*/
    case variableCompression            = -2   /*compression ID for variable-sized compression*/
    case twoToOne                       = 1
    case eightToThree                   = 2
    case threeToOne                     = 3
    case sixToOne                       = 4
    case sixToOnePacketSize             = 8
    case threeToOnePacketSize           = 16
}

enum SoundFormat : UInt16 {
    case firstSoundFormat               = 0x0001 /*general sound format*/
    case secondSoundFormat              = 0x0002 /*special sampled sound format (HyperCard)*/
};

enum SoundHeaderEncode : UInt8 {
    case stdSH                          = 0x00  /*Standard sound header encode value*/
    case extSH                          = 0xFF  /*Extended sound header encode value*/
    case cmpSH                          = 0xFE  /*Compressed sound header encode value*/
};

/*command numbers for SndDoCommand and SndDoImmediate*/
enum SoundCommand : UInt16 {
    case nullCmd                        = 0
    case quietCmd                       = 3
    case flushCmd                       = 4
    case reInitCmd                      = 5
    case waitCmd                        = 10
    case pauseCmd                       = 11
    case resumeCmd                      = 12
    case callBackCmd                    = 13
    case syncCmd                        = 14
    case availableCmd                   = 24
    case versionCmd                     = 25
    case volumeCmd                      = 46   /*sound manager 3.0 or later only*/
    case getVolumeCmd                   = 47   /*sound manager 3.0 or later only*/
    case clockComponentCmd              = 50   /*sound manager 3.2.1 or later only*/
    case getClockComponentCmd           = 51   /*sound manager 3.2.1 or later only*/
    case scheduledSoundCmd              = 52   /*sound manager 3.3 or later only*/
    case linkSoundComponentsCmd         = 53   /*sound manager 3.3 or later only*/
    case soundCmd                       = 80
    case bufferCmd                      = 81
    case rateMultiplierCmd              = 86
    case getRateMultiplierCmd           = 87
};

enum InitOptions : UInt16 {
    case initChanLeft                   = 0x0002 /*left stereo channel*/
    case initChanRight                  = 0x0003 /*right stereo channel*/
    case initNoInterp                   = 0x0004 /*no linear interpolation*/
    case initNoDrop                     = 0x0008 /*no drop-sample conversion*/
    case initMono                       = 0x0080 /*monophonic channel*/
    case initStereo                     = 0x00C0 /*stereo channel*/
    case initMACE3                      = 0x0300 /*MACE 3:1*/
    case initMACE6                      = 0x0400 /*MACE 6:1*/
}

/*Format Types*/
enum Format {
    case kSoundNotCompressed            = 'NONE', /*sound is not compressed*/
    case k8BitOffsetBinaryFormat        = 'raw ', /*8-bit offset binary*/
    case k16BitBigEndianFormat          = 'twos', /*16-bit big endian*/
    case k16BitLittleEndianFormat       = 'sowt', /*16-bit little endian*/
    case kFloat32Format                 = 'fl32', /*32-bit floating point*/
    case kFloat64Format                 = 'fl64', /*64-bit floating point*/
    case k24BitFormat                   = 'in24', /*24-bit integer*/
    case k32BitFormat                   = 'in32', /*32-bit integer*/
    case k32BitLittleEndianFormat       = '23ni', /*32-bit little endian integer */
    case kMACE3Compression              = 'MAC3', /*MACE 3:1*/
    case kMACE6Compression              = 'MAC6', /*MACE 6:1*/
    case kCDXA4Compression              = 'cdx4', /*CD/XA 4:1*/
    case kCDXA2Compression              = 'cdx2', /*CD/XA 2:1*/
    case kIMACompression                = 'ima4', /*IMA 4:1*/
    case kULawCompression               = 'ulaw', /*µLaw 2:1*/
    case kALawCompression               = 'alaw', /*aLaw 2:1*/
    case kMicrosoftADPCMFormat          = 0x6D730002, /*Microsoft ADPCM - ACM code 2*/
    case kDVIIntelIMAFormat             = 0x6D730011, /*DVI/Intel IMA ADPCM - ACM code 17*/
    case kMicrosoftGSMCompression       = 0x6D730031, /*Microsoft GSM 6.10 - ACM code 49*/
    case kDVAudioFormat                 = 'dvca', /*DV Audio*/
    case kQDesignCompression            = 'QDMC', /*QDesign music*/
    case kQDesign2Compression           = 'QDM2', /*QDesign2 music*/
    case kQUALCOMMCompression           = 'Qclp', /*QUALCOMM PureVoice*/
    case kOffsetBinary                  = k8BitOffsetBinaryFormat, /*for compatibility*/
    case kTwosComplement                = k16BitBigEndianFormat, /*for compatibility*/
    case kLittleEndianFormat            = k16BitLittleEndianFormat, /*for compatibility*/
    case kMPEGLayer3Format              = 0x6D730055, /*MPEG Layer 3, CBR only (pre QT4.1)*/
    case kFullMPEGLay3Format            = '.mp3', /*MPEG Layer 3, CBR & VBR (QT4.1 and later)*/
    case kVariableDurationDVAudioFormat = 'vdva', /*Variable Duration DV Audio*/
    case kMPEG4AudioFormat              = 'mp4a'
};

/*
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   typedefs
  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

struct SndCommand {
  unsigned short      cmd;
  short               param1;
  long                param2;
};
typedef struct SndCommand               SndCommand;

struct ModRef {
  unsigned short      modNumber;
  long                modInit;
};
typedef struct ModRef                   ModRef;
struct SndListResource {
  short               format;
  short               numModifiers;
  ModRef              modifierPart[1];
  short               numCommands;
  SndCommand          commandPart[1];
  UInt8               dataPart[1];
};
typedef struct SndListResource          SndListResource;
typedef SndListResource *               SndListPtr;
typedef SndListPtr *                    SndListHandle;
typedef SndListHandle                   SndListHndl;
/*HyperCard sound resource format*/
struct Snd2ListResource {
  short               format;
  short               refCount;
  short               numCommands;
  SndCommand          commandPart[1];
  UInt8               dataPart[1];
};
typedef struct Snd2ListResource         Snd2ListResource;
typedef Snd2ListResource *              Snd2ListPtr;
typedef Snd2ListPtr *                   Snd2ListHandle;
typedef Snd2ListHandle                  Snd2ListHndl;
struct SoundHeader {
  unsigned long       samplePtr;              /*if NIL then samples are in sampleArea*/
  unsigned long       length;                 /*length of sound in bytes*/
  UnsignedFixed       sampleRate;             /*sample rate for this sound*/
  unsigned long       loopStart;              /*start of looping portion*/
  unsigned long       loopEnd;                /*end of looping portion*/
  UInt8               encode;                 /*header encoding*/
  UInt8               baseFrequency;          /*baseFrequency value*/
  UInt8               sampleArea[1];          /*space for when samples follow directly*/
};
typedef struct SoundHeader              SoundHeader;
typedef SoundHeader *                   SoundHeaderPtr;
struct CmpSoundHeader {
  unsigned long       samplePtr;              /*if nil then samples are in sample area*/
  unsigned long       numChannels;            /*number of channels i.e. mono = 1*/
  UnsignedFixed       sampleRate;             /*sample rate in Apples Fixed point representation*/
  unsigned long       loopStart;              /*loopStart of sound before compression*/
  unsigned long       loopEnd;                /*loopEnd of sound before compression*/
  UInt8               encode;                 /*data structure used , stdSH, extSH, or cmpSH*/
  UInt8               baseFrequency;          /*same meaning as regular SoundHeader*/
  unsigned long       numFrames;              /*length in frames ( packetFrames or sampleFrames )*/
  Float80             AIFFSampleRate;         /*IEEE sample rate*/
  unsigned long       markerChunk;            /*sync track*/
  OSType              format;                 /*data format type, was futureUse1*/
  unsigned long       futureUse2;             /*reserved by Apple*/
  unsigned long       stateVars;              /*pointer to State Block*/
  unsigned long       leftOverSamples;        /*used to save truncated samples between compression calls*/
  short               compressionID;          /*0 means no compression, non zero means compressionID*/
  unsigned short      packetSize;             /*number of bits in compressed sample packet*/
  unsigned short      snthID;                 /*resource ID of Sound Manager snth that contains NRT C/E*/
  unsigned short      sampleSize;             /*number of bits in non-compressed sample*/
  UInt8               sampleArea[1];          /*space for when samples follow directly*/
};
typedef struct CmpSoundHeader           CmpSoundHeader;
typedef CmpSoundHeader *                CmpSoundHeaderPtr;
struct ExtSoundHeader {
  unsigned long       samplePtr;              /*if nil then samples are in sample area*/
  unsigned long       numChannels;            /*number of channels,  ie mono = 1*/
  UnsignedFixed       sampleRate;             /*sample rate in Apples Fixed point representation*/
  unsigned long       loopStart;              /*same meaning as regular SoundHeader*/
  unsigned long       loopEnd;                /*same meaning as regular SoundHeader*/
  UInt8               encode;                 /*data structure used , stdSH, extSH, or cmpSH*/
  UInt8               baseFrequency;          /*same meaning as regular SoundHeader*/
  unsigned long       numFrames;              /*length in total number of frames*/
  Float80             AIFFSampleRate;         /*IEEE sample rate*/
  unsigned long       markerChunk;            /*sync track*/
  unsigned long       instrumentChunks;       /*AIFF instrument chunks*/
  unsigned long       AESRecording;
  unsigned short      sampleSize;             /*number of bits in sample*/
  unsigned short      futureUse1;             /*reserved by Apple*/
  unsigned long       futureUse2;             /*reserved by Apple*/
  unsigned long       futureUse3;             /*reserved by Apple*/
  unsigned long       futureUse4;             /*reserved by Apple*/
  UInt8               sampleArea[1];          /*space for when samples follow directly*/
};
typedef struct ExtSoundHeader           ExtSoundHeader;
typedef ExtSoundHeader *                ExtSoundHeaderPtr;
union SoundHeaderUnion {
  SoundHeader         stdHeader;
  CmpSoundHeader      cmpHeader;
  ExtSoundHeader      extHeader;
};
typedef union SoundHeaderUnion          SoundHeaderUnion;
