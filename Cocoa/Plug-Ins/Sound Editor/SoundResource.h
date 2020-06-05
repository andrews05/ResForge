#import <Foundation/Foundation.h>
#import "ResKnifeResourceProtocol.h"

@interface SoundResource : NSObject

- (instancetype)initWithResource:(id <ResKnifeResource>)resource;

@end
