#import <Cocoa/Cocoa.h>

#import "ResKnifePluginProtocol.h"
#import "ResKnifeResourceProtocol.h"

@interface NovaWindowController : NSWindowController <ResKnifePluginProtocol>
{
	id <ResKnifeResourceProtocol>	resource;
}

- (IBAction)toggleResID:(id)sender;

@end
