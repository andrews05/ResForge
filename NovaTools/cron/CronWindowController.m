#import "CronWindowController.h"

@implementation CronWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"cron"];
	if( !self ) return nil;
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( [newResource name] && ![[newResource name] isEqualToString:@""] )
		[[self window] setTitle:[NSString stringWithFormat:@"%@: %@", [[self window] title], [newResource name]]];
	return self;
}

// date format for start and end:
//	%e/%1m/%Y == 1/1/2000

@end
