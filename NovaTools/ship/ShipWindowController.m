#import "ShipWindowController.h"

@implementation ShipWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	if (self = [self initWithWindowNibName:@"ship"]) {
		
	}
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self showWindow:self];
}

@end
