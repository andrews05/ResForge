#import "BoomWindowController.h"

@implementation BoomWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"boom"];
	if( !self ) return self;
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( ![[resource name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"Explosion: %@", [resource name]]];
	return self;
}

@end
