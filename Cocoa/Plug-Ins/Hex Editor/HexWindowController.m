#import "HexWindowController.h"
#import "HexTextView.h"

@implementation HexWindowController

NSString *ResourceWillChangeNotification			= @"ResourceWillChangeNotification";
NSString *ResourceNameWillChangeNotification		= @"ResourceNameWillChangeNotification";
NSString *ResourceTypeWillChangeNotification		= @"ResourceTypeWillChangeNotification";
NSString *ResourceIDWillChangeNotification			= @"ResourceIDWillChangeNotification";
NSString *ResourceAttributesWillChangeNotification	= @"ResourceAttributesWillChangeNotification";
NSString *ResourceDataWillChangeNotification		= @"ResourceDataWillChangeNotification";

NSString *ResourceNameDidChangeNotification			= @"ResourceNameDidChangeNotification";
NSString *ResourceTypeDidChangeNotification			= @"ResourceTypeDidChangeNotification";
NSString *ResourceIDDidChangeNotification			= @"ResourceIDDidChangeNotification";
NSString *ResourceAttributesDidChangeNotification	= @"ResourceAttributesDidChangeNotification";
NSString *ResourceDataDidChangeNotification			= @"ResourceDataDidChangeNotification";
NSString *ResourceDidChangeNotification				= @"ResourceDidChangeNotification";

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"HexWindow"];
	if( !self ) return self;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	resource = [newResource retain];
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( ![[resource name] isEqualToString:@""] )
		[[self window] setTitle:[resource name]];
	return self;
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
	
	// swap text views to instances of my class instead
	[offset swapForHexTextView];
	[hex swapForHexTextView];
	[ascii swapForHexTextView];
	
	// turn off the background for the offset column (IB is broken when it comes to this)
	[offset setDrawsBackground:NO];
	[[offset enclosingScrollView] setDrawsBackground:NO];
	
	// set up tab, shift-tab and enter behaviour
	[hex setFieldEditor:YES];
	[ascii setFieldEditor:YES];
	
	// insert the resources' data into the text fields
	[self refreshData:[resource data]];
	
	// we don't want this notification until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// put other notifications here too, just for togetherness
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[offset enclosingScrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[hex enclosingScrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[ascii enclosingScrollView] contentView]];
	
	// finally, show the window
	[self showWindow:self];
}

- (void)viewDidScroll:(NSNotification *)notification
{
	// get object refs for increased speed
	NSClipView *object		= (NSClipView *) [notification object];
	NSClipView *offsetClip	= [[offset enclosingScrollView] contentView];
	NSClipView *hexClip		= [[hex enclosingScrollView] contentView];
	NSClipView *asciiClip	= [[ascii enclosingScrollView] contentView];
	
	// due to a bug in -[NSView setPostsBoundsChangedNotifications:] (it basically doesn't work), I am having to work around it by removing myself from the notification center and restoring things later on!
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:nil];
	
	// when a view scrolls, update the other two
	if( object != offsetClip )
	{
//		[offsetClip setPostsBoundsChangedNotifications:NO];
		[offsetClip setBoundsOrigin:[object bounds].origin];
//		[offsetClip setPostsBoundsChangedNotifications:YES];
	}
	
	if( object != hexClip )
	{
//		[hexClip setPostsBoundsChangedNotifications:NO];
		[hexClip setBoundsOrigin:[object bounds].origin];
//		[hexClip setPostsBoundsChangedNotifications:YES];
	}
	
	if( object != asciiClip )
	{
//		[asciiClip setPostsBoundsChangedNotifications:NO];
		[asciiClip setBoundsOrigin:[object bounds].origin];
//		[asciiClip setPostsBoundsChangedNotifications:YES];
	}
	
	// restore notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:offsetClip];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:hexClip];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:asciiClip];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for other resource notifications)
	if( [notification object] == (id)resource )
		[self refreshData:[resource data]];
}

- (void)refreshData:(NSData *)data;
{
	// save selections
	NSRange hexSelection = [hex selectedRange];
	NSRange asciiSelection = [ascii selectedRange];
	
	// clear delegates (see HexEditorDelegate class for explanation of why)
	id oldDelegate = [hex delegate];
	[hex setDelegate:nil];
	[ascii setDelegate:nil];
	
	// do stuff with data
	[offset	setString:[hexDelegate offsetRepresentation:data]];
	[hex	setString:[hexDelegate hexRepresentation:data]];
	[ascii	setString:[hexDelegate asciiRepresentation:data]];
	
	// restore selections (this is the dumbest way to do it, but it'll do for now)
	[hex setSelectedRange:hexSelection];
	[ascii setSelectedRange:asciiSelection];
	
	// restore delegates
	[hex setDelegate:oldDelegate];
	[ascii setDelegate:oldDelegate];
}

- (id)resource
{
	return resource;
}

- (NSData *)data
{
	return [resource data];
}

@end
