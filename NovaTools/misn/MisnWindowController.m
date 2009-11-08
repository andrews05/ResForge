#import "MisnWindowController.h"

@implementation MisnWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	self = [self initWithWindowNibName:@"misn"];
	if( !self ) return nil;
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self showWindow:self];
}

@end
