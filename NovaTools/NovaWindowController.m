#import "NovaWindowController.h"
#import "BoomWindowController.h"
#import "CharWindowController.h"
#import "ColrWindowController.h"
#import "CronWindowController.h"
#import "DescWindowController.h"

@implementation NovaWindowController

- (id)initWithResource:(id)newResource
{
	id oldSelf = self;
	NSData *classData = [[(id <ResKnifeResourceProtocol>)newResource type] dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	NSString *className = [[[NSString stringWithCString:[classData bytes] length:[classData length]] capitalizedString] stringByAppendingString:@"WindowController"];
	if( [className isEqualToString:@"Yea(R)WindowController"] ) className = @"YearWindowController";
	self = [[NSClassFromString(className) alloc] initWithResource:newResource];
	[oldSelf release];
	if( !self ) return nil;
	
	// do global stuff here
	resource = [newResource retain];
	
	return self;
}

- (id)initWithResources:(id)newResource, ...
{
	return nil;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
		
	// insert the resources' data into the text fields
//	[self refreshData:[resource data]];
	
	// we don't want this notification until we have a window!
	// bug: only registers for notifications on the resource we're editing, need dependant resources too (pass nil for object?)
//	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (IBAction)toggleResID:(id)sender
{
	// toggles between resource IDs and index numbers
	NSLog( @"%@", [resource type] );
}

@end
