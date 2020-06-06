#import <Cocoa/Cocoa.h>
#import <AVKit/AVKit.h>

#import "ResKnifePluginProtocol.h"
#import "SoundResource.h"

@interface SoundWindowController : NSWindowController <ResKnifePlugin>
@property SoundResource *sound;
@property IBOutlet AVPlayerView *player;

@end
