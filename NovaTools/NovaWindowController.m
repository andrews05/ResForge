#import "NovaWindowController.h"
#import "BoomWindowController.h"
#import "CharWindowController.h"
#import "ColrWindowController.h"
#import "CronWindowController.h"
#import "DescWindowController.h"

@implementation NovaWindowController

- (id)initWithResource:(id)newResource
{
	NSString *asciiType = NSLocalizedStringFromTable( [resource type], @"Resource Types", nil );
	
	resource = [newResource retain];
	
	NSLog( @"%s", [[resource type] lossyCString] );
	NSLog( [[[resource type] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES] description] );
	if( [asciiType isEqualToString:@"boom"] )
	{
		id oldSelf = self;
		self = [[BoomWindowController alloc] initWithResource:newResource];
		[oldSelf release];
	}
	if( [asciiType isEqualToString:@"char"] )
	{
		id oldSelf = self;
		self = [[CharWindowController alloc] initWithResource:newResource];
		[oldSelf release];
	}
	if( [asciiType isEqualToString:@"colr"] )
	{
		id oldSelf = self;
		self = [[ColrWindowController alloc] initWithResource:newResource];
		[oldSelf release];
	}
	if( [asciiType isEqualToString:@"cron"] )
	{
		id oldSelf = self;
		self = [[CronWindowController alloc] initWithResource:newResource];
		[oldSelf release];
	}
	if( [asciiType isEqualToString:@"desc"] )
	{
		id oldSelf = self;
		self = [[DescWindowController alloc] initWithResource:newResource];
		[oldSelf release];
	}
	if( !self ) return nil;
	
	// do global stuff here
	
	return self;
}

- (id)initWithResources:(id)newResource, ...
{
	return nil;
}

@end
