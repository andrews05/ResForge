#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ResKnifeResourceProtocol.h"

@interface SoundResource : NSObject {
    AudioStreamBasicDescription streamDesc;
    AudioQueueRef queueRef;
    AudioQueueBufferRef bufferRef;
}
@property (readonly) BOOL valid;

+ (NSDictionary *)supportedFormats;

- (instancetype)initWithResource:(id <ResKnifeResource>)resource;
- (instancetype)initWithURL:(NSURL *)url format:(OSType)format channels:(UInt32)channels sampleRate:(Float64)sampleRate;
- (void)play;
- (void)stop;
- (void)exportToURL:(NSURL *)url;
- (OSType)format;
- (UInt32)channels;
- (Float64)sampleRate;
- (Float64)duration;

@end
