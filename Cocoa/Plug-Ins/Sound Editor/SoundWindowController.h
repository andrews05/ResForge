#import <Cocoa/Cocoa.h>
#import <AVKit/AVKit.h>

#import "ResKnifePluginProtocol.h"
#import "SoundResource.h"

@interface SoundWindowController : NSWindowController <ResKnifePlugin>
@property id <ResKnifeResource> resource;
@property SoundResource *sound;
@property IBOutlet NSButton *playButton;
@property IBOutlet NSButton *exportButton;
@property IBOutlet NSTextField *format;
@property IBOutlet NSTextField *channels;
@property IBOutlet NSTextField *sampleRate;

@end
