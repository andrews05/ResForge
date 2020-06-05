#import <Cocoa/Cocoa.h>
#import <AVKit/AVKit.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface SoundWindowController : NSWindowController <ResKnifePlugin>
@property id <ResKnifeResource> resource;
@property IBOutlet AVPlayerView *player;

@end
