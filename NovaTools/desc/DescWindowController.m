#import "DescWindowController.h"

@implementation DescWindowController

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
{
	self = [self initWithWindowNibName:@"desc"];
	if( !self ) return nil;
	return self;
}

- (IBAction)chooseMovieFile:(id)sender
{
	
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self showWindow:self];
}

@end
