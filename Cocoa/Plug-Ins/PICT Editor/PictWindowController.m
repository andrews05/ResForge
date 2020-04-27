#import "PictWindowController.h"
//#import "Element.h"
#import <stdarg.h>

@interface PictWindowController ()
@property (strong) id<ResKnifeResource> resource;
@end

@implementation PictWindowController
@synthesize imageView;
@synthesize resource;

- (instancetype)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"PictWindow"];
	if( !self ) return nil;
	
	resource = newResource;
	
	// load the window from the nib
	[self window];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// set the window's title
		[[self window] setTitle:[resource defaultWindowTitle]];
		//SetWindowAlternateTitle( (WindowRef) [[self window] windowRef], (CFStringRef) [NSString stringWithFormat:@"%@ %@: �%@�", [resource type], [resource resID], [resource name]] );
	
	NSImage *image = [[NSImage alloc] initWithData:[resource data]];
	if( image )
	{
		// resize the window to the size of the image
		//[[self window] setContentSize:[image size]];
	
		// update image view with PICT
		[imageView setImage:image];
	}
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// finally, show the window
	[self showWindow:self];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [resource defaultWindowTitle];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for notifications on other resource objects)
	if( [notification object] == (id)resource )
	{
		// refresh image
		NSImage *image = [[NSImage alloc] initWithData:[resource data]];
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
