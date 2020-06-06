#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ResKnifeResourceProtocol.h"

@interface SoundResource : NSObject {
    AudioStreamBasicDescription streamDesc;
    AudioQueueRef queueRef;
    AudioQueueBufferRef bufferRef;
}

+ (NSDictionary *)supportedFormats;

- (instancetype)initWithResource:(id <ResKnifeResource>)resource;
- (void)play;
- (void)stop;
- (void)exportToURL:(NSURL *)url;
- (OSType)format;
- (UInt32)channels;
- (Float64)sampleRate;

@end
