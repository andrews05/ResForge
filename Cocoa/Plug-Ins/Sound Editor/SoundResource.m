#import "SoundResource.h"
#import "BTBinaryStreamReader.h"
#include "Sound.h"

@implementation SoundResource

- (instancetype)initWithResource:(id <ResKnifeResource>)resource
{
    if (self = [super init]) {
        [self parse:resource.data];
    }
    return self;
}

- (BOOL)parse:(NSData *)data
{
    BTBinaryStreamReader *stream = [[BTBinaryStreamReader alloc] initWithData:data andSourceByteOrder:CFByteOrderBigEndian];
    UInt16 soundFormat = [stream readInt16];
    if (soundFormat == firstSoundFormat) {
        SndListResource list = {
            .format = soundFormat,
            .numModifiers = [stream readInt16],
            .modifierPart = {
                {
                    .modNumber = [stream readInt16],
                    .modInit = [stream readInt32]
                }
            },
            .numCommands = [stream readInt16],
            .commandPart = {
                {
                    .cmd = [stream readInt16],
                    .param1 = [stream readInt16],
                    .param2 = [stream readInt32]
                }
            }
        };
        if (list.numModifiers != 1) return false;
        if (list.modifierPart[0].modNumber != sampledSynth) return false;
        if (list.numCommands != 1) return false;
        if (list.commandPart[0].cmd != dataOffsetFlag+bufferCmd) return false;
    } else if (soundFormat == secondSoundFormat) {
        Snd2ListResource list = {
            .format = soundFormat,
            .refCount = [stream readInt16],
            .numCommands = [stream readInt16],
            .commandPart = {
                {
                    .cmd = [stream readInt16],
                    .param1 = [stream readInt16],
                    .param2 = [stream readInt32]
                }
            }
        };
        if (list.numCommands != 1) return false;
        if (list.commandPart[0].cmd != dataOffsetFlag+bufferCmd) return false;
    } else {
        return false;
    }
    
    SoundHeader header = {
        .samplePtr = (Ptr)(size_t)[stream readInt32],
        .length = [stream readInt32],
        .sampleRate = [stream readInt32],
        .loopStart = [stream readInt32],
        .loopEnd = [stream readInt32],
        .encode = [stream readInt8],
        .baseFrequency = [stream readInt8]
    };
    unsigned long numChannels, numFrames;
    unsigned short sampleSize;
    OSType format;
    if (header.encode == stdSH) {
        numChannels = 1;
        numFrames = header.length;
        sampleSize = 8;
        format = k8BitOffsetBinaryFormat;
    } else if (header.encode == extSH) {
        ExtSoundHeader extHeader = {
            .numFrames = [stream readInt32],
            .AIFFSampleRate = *(extended80*)[[stream readDataOfLength:10] bytes],
            .markerChunk = (Ptr)(size_t)[stream readInt32],
            .instrumentChunks = (Ptr)(size_t)[stream readInt32],
            .AESRecording = (Ptr)(size_t)[stream readInt32],
            .sampleSize = [stream readInt16],
            .futureUse1 = [stream readInt16],
            .futureUse2 = [stream readInt32],
            .futureUse3 = [stream readInt32],
            .futureUse4 = [stream readInt32]
        };
        numChannels = header.length;
        numFrames = extHeader.numFrames;
        sampleSize = extHeader.sampleSize;
        format = sampleSize == 8 ? k8BitOffsetBinaryFormat : k16BitLittleEndianFormat;
    } else if (header.encode == cmpSH) {
        CmpSoundHeader cmpHeader = {
            .numFrames = [stream readInt32],
            .AIFFSampleRate = *(extended80*)[[stream readDataOfLength:10] bytes],
            .markerChunk = (Ptr)(size_t)[stream readInt32],
            .format = [stream readInt32],
            .futureUse2 = [stream readInt32],
            .stateVars = (StateBlockPtr)(size_t)[stream readInt32],
            .leftOverSamples = (LeftOverBlockPtr)(size_t)[stream readInt32],
            .compressionID = [stream readInt16],
            .packetSize = [stream readInt16],
            .snthID = [stream readInt16],
            .sampleSize = [stream readInt16]
        };
        numChannels = header.length;
        numFrames = cmpHeader.numFrames;
        sampleSize = cmpHeader.sampleSize;
        if (cmpHeader.compressionID == threeToOne) {
            format = kMACE3Compression;
        } else if (cmpHeader.compressionID == sixToOne) {
            format = kMACE6Compression;
        } else {
            format = cmpHeader.format;
        }
    } else {
        return false;
    }
    return true;
}

@end
