#import "MisnWindowController.h"

@implementation MisnWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	if (self = [self initWithWindowNibName:@"misn"]) {
		
	}
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self showWindow:self];
}

@end
