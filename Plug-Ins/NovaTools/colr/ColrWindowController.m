#import "ColrWindowController.h"

@implementation ColrWindowController

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
{
	self = [self initWithWindowNibName:@"colr"];
	if( !self ) return nil;
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self showWindow:self];
}

@end
