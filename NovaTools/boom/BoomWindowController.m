#import "BoomWindowController.h"

@implementation BoomWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"boom"];
	if( !self ) return nil;
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( [newResource name] && ![[newResource name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", [[self window] title], [newResource name]]];
	return self;
}

@end
