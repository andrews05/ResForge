#import "PictWindowController.h"
//#import "Element.h"
#import <stdarg.h>

@implementation PictWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"PictWindow"];
	if( !self ) return nil;
	
	resource = [newResource retain];
	
	// load the window from the nib
	[self window];
	return self;
}

- (id)initWithResources:(id)newResource, ...
{
	return nil;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[(id)resource autorelease];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// set the window's title
	if( ![[resource name] isEqualToString:@""] )
	{
		[[self window] setTitle:[resource name]];
		SetWindowAlternateTitle( (WindowRef) [[self window] windowRef], (CFStringRef) [NSString stringWithFormat:@"%@ %@: Ò%@Ó", [resource type], [resource resID], [resource name]] );
	}
	
	NSImage *image = [[[NSImage alloc] initWithData:[resource data]] autorelease];
	if( image )
	{
		// resize the window to the size of the image
		[[self window] setContentSize:[image size]];
	
		// update image view with PICT
		[imageView setImage:image];
	}
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for notifications on other resource objects)
	if( [notification object] == (id)resource )
	{
		// refresh image
		NSImage *image = [[[NSImage alloc] initWithData:[resource data]] autorelease];
		if( image )
		{
			// resize the window to the size of the image
			[[self window] setContentSize:[image size]];
		
			// update image view with PICT
			[imageView setImage:image];
		}
	}
}

@end
