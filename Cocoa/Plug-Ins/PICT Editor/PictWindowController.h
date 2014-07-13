#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface PictWindowController : NSWindowController <ResKnifePlugin>
{
	IBOutlet NSImageView	*imageView;
	
	id <ResKnifeResource>	resource;
}

@end
