#import "MisnWindowController.h"

@implementation MisnWindowController

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
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
