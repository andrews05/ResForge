#import "HexWindowController.h"

@implementation HexWindowController

NSString *ResourceChangedNotification = @"ResourceChangedNotification";

+ (void)initialize
{
	// causes window controller to use HexTextViews wherever it would previously use NSTextView
    [HexTextView poseAsClass:[NSTextView class]];
}

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"HexWindow"];
	if( !self ) return self;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	resource = [newResource retain];
	
	// load the window
	[self setWindowFrameAutosaveName:@"Hexadecimal Editor"];
//	[self setShouldCascadeWindows:YES];
	[self window];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[resource autorelease];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// swap text views to instances of my class instead
	//	An experianced NeXT programmer told me that poseAsClass would come back to bite me in the ass at some point, and that I should instead instanciate some HexTextViews and swap them in for now, and use IB do do things properly once IB is fixed. But, for now I think I'll not bother :-P
	
	// we don't want this notification until we have a window!
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDidChange:) name:ResourceChangedNotification object:nil];
	
	// put other notifications here too, just for togetherness
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[offset enclosingScrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[hex enclosingScrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[ascii enclosingScrollView] contentView]];
	
	// insert the resources' data into the text fields
	[self refreshData:[(id <ResKnifeResourceProtocol>)resource data]];
	
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

- (void)resourceDidChange:(NSNotification *)notification
{
	// see if it's our resource which got changed (we receive notifications for any resource being changed, allowing multi-resource editors)
	if( [notification object] == resource )
		[self refreshData:[(id <ResKnifeResourceProtocol>)resource data]];
}

- (void)refreshData:(NSData *)data;
{
	// clear delegates (see HexEditorDelegate class for explanation of why)
	id oldDelegate = [hex delegate];
	[hex setDelegate:nil];
	[ascii setDelegate:nil];
	
	// do stuff with data
	[offset	setString:[hexDelegate offsetRepresentation:data]];
	[hex	setString:[hexDelegate hexRepresentation:data]];
	[ascii	setString:[hexDelegate asciiRepresentation:data]];
	
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
	return [(id <ResKnifeResourceProtocol>)resource data];
}

@end
