#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface PictWindowController : NSWindowController <ResKnifePluginProtocol>
{
	IBOutlet NSImageView	*imageView;
	
	id <ResKnifeResourceProtocol>	resource;
}

@end
