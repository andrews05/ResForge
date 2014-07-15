#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface PictWindowController : NSWindowController <ResKnifePlugin>
@property (weak) IBOutlet NSImageView *imageView;

@end
