#import "BoomWindowController.h"

@implementation BoomWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"boom"];
	if( !self ) return nil;
	
	boomRec = (BoomRec *)calloc(1,sizeof(BoomRec));
	
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self showWindow:self];
}

@end
