#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ResKnifeResourceProtocol.h"

@interface SoundResource : NSObject {
    AudioStreamBasicDescription streamDesc;
    AudioQueueRef queueRef;
    AudioQueueBufferRef bufferRef;
}

- (instancetype)initWithResource:(id <ResKnifeResource>)resource;
- (void)play;
- (void)stop;

@end
