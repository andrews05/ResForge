#import "SoundResource.h"
#import "BTBinaryStreamReader.h"
#include "Sound.h"

@implementation SoundResource

+ (NSDictionary *)supportedFormats {
    static NSDictionary *formats = nil;
    if (!formats) {
        formats = @{
            GetNSStringFromOSType(k8BitOffsetBinaryFormat): @"8 bit uncompressed",
            GetNSStringFromOSType(k16BitBigEndianFormat): @"16 bit uncompressed",
            GetNSStringFromOSType(kIMACompression): @"IMA 4:1",
            GetNSStringFromOSType(kALawCompression): @"A-Law 2:1",
            GetNSStringFromOSType(kULawCompression): @"µ-Law 2:1",
        };
    }
    return formats;
}

- (instancetype)initWithResource:(id <ResKnifeResource>)resource {
    if (self = [super init]) {
        _valid = [self parse:resource.data];
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)url format:(OSType)format channels:(UInt32)channels sampleRate:(Float64)sampleRate {
    if (self = [super init]) {
        OSStatus err;
        ExtAudioFileRef fRef;
        UInt32 streamDescSize = sizeof(streamDesc);
        err = ExtAudioFileOpenURL((__bridge CFURLRef _Nonnull)(url), &fRef);
        err = ExtAudioFileGetProperty(fRef, kExtAudioFileProperty_FileDataFormat, &streamDescSize, &streamDesc);

        [self setStreamDescriptionFormat:format channels:channels sampleRate:sampleRate];
        err = ExtAudioFileSetProperty(fRef, kExtAudioFileProperty_ClientDataFormat, streamDescSize, &streamDesc);
    }
    return self;
}

- (BOOL)setStreamDescriptionFormat:(OSType)format channels:(UInt32)channels sampleRate:(Float64)sampleRate {
    if (sampleRate > 0) {
        streamDesc.mSampleRate = sampleRate;
    }
    if (channels > 0) {
        streamDesc.mChannelsPerFrame = channels;
    }
    streamDesc.mFormatID = format;
    streamDesc.mFormatFlags = 0;
    if (format == kIMACompression) {
        streamDesc.mBitsPerChannel = 0;
        streamDesc.mBytesPerFrame = 0;
        streamDesc.mFramesPerPacket = 64;
        streamDesc.mBytesPerPacket = 34;
    } else {
        if (format == k8BitOffsetBinaryFormat) {
            streamDesc.mBitsPerChannel = 8;
            streamDesc.mFormatID = kAudioFormatLinearPCM;
        } else if (format == k16BitBigEndianFormat) {
            streamDesc.mBitsPerChannel = 16;
            streamDesc.mFormatID = kAudioFormatLinearPCM;
            streamDesc.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian;
        } else if (format == kALawCompression || format == kULawCompression) {
            streamDesc.mBitsPerChannel = 8;
        } else {
            return false;
        }
        streamDesc.mBytesPerFrame = (UInt32)((streamDesc.mBitsPerChannel/8) * streamDesc.mChannelsPerFrame);
        streamDesc.mFramesPerPacket = 1;
        streamDesc.mBytesPerPacket = streamDesc.mBytesPerFrame * streamDesc.mFramesPerPacket;
    }
    return true;
}

- (BOOL)parse:(NSData *)data {
    // Read sound headers
    BTBinaryStreamReader *stream = [[BTBinaryStreamReader alloc] initWithData:data andSourceByteOrder:CFByteOrderBigEndian];
    UInt16 soundFormat = [stream readInt16];
    if (soundFormat == firstSoundFormat) {
        SndListResource list = {
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
        format = sampleSize == 8 ? k8BitOffsetBinaryFormat : k16BitBigEndianFormat;
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
        format = cmpHeader.format;
    } else {
        return false;
    }
    
    // Construct stream description
    BOOL valid = [self setStreamDescriptionFormat:format channels:(UInt32)numChannels sampleRate:FixedToFloat(header.sampleRate)];
    if (!valid) return false;

    // Setup audio queue
    UInt32 byteSize = (UInt32)(data.length - stream.bytesRead);
    UInt32 expectedSize = (UInt32)(numFrames * streamDesc.mBytesPerPacket);
    if (byteSize > expectedSize) byteSize = expectedSize;
    OSStatus err;
    err = AudioQueueNewOutput(&streamDesc, QueueNoop, NULL, NULL, NULL, 0, &queueRef);
    err = AudioQueueAllocateBuffer(queueRef, byteSize, &bufferRef);
    bufferRef->mAudioDataByteSize = byteSize;
    [data getBytes:bufferRef->mAudioData range:NSMakeRange(stream.bytesRead, byteSize)];
    return true;
}

- (void)play {
    if (!queueRef) return;
    OSStatus err;
    err = AudioQueueReset(queueRef);
    err = AudioQueueEnqueueBuffer(queueRef, bufferRef, 0, NULL);
    err = AudioQueueStart(queueRef, NULL);
}

- (void)stop {
    if (!queueRef) return;
    OSStatus err;
    err = AudioQueueReset(queueRef);
}

- (void)exportToURL:(NSURL *)url {
    if (!bufferRef) return;
    OSStatus err;
    AudioFileID fRef;
    UInt32 bytes = bufferRef->mAudioDataByteSize;
    AudioFormatID formatID = (streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian) ? kAudioFileAIFFType : kAudioFileAIFCType;
    err = AudioFileCreateWithURL((__bridge CFURLRef _Nonnull)(url), formatID, &streamDesc, kAudioFileFlags_EraseFile, &fRef);
    err = AudioFileWriteBytes(fRef, false, 0, &bytes, bufferRef->mAudioData);
    err = AudioFileClose(fRef);
}

- (OSType)format {
    if (streamDesc.mFormatFlags & kAudioFormatFlagIsBigEndian) {
        return k16BitBigEndianFormat;
    } else if (streamDesc.mFormatID == kAudioFormatLinearPCM) {
        return k8BitOffsetBinaryFormat;
    } else {
        return streamDesc.mFormatID;
    }
}

- (UInt32)channels {
    return streamDesc.mChannelsPerFrame;
}

- (Float64)sampleRate {
    return streamDesc.mSampleRate;
}

- (Float64)duration {
    if (!streamDesc.mBytesPerPacket) return 0;
    UInt32 numFrames = (bufferRef->mAudioDataByteSize * streamDesc.mFramesPerPacket) / streamDesc.mBytesPerPacket;
    return numFrames / streamDesc.mSampleRate;
}

void QueueNoop(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {}

@end
