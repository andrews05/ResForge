#import "HexWindowController.h"
#import "HexTextView.h"
#import "FindSheetController.h"

@implementation HexWindowController

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"HexWindow"];
	if( !self ) return self;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	undoManager = [[NSUndoManager alloc] init];
	resource = [newResource retain];
	bytesPerRow = 16;
	
	// load the window from the nib file and set it's title
	[self window];	// implicitly loads nib
	if( ![[resource name] isEqualToString:@""] )
		[[self window] setTitle:[resource name]];
	return self;
}

- (id)initWithResources:(id)newResource, ...
{
	[undoManager release];
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	
	// put other notifications here too, just for togetherness
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[offset enclosingScrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[hex enclosingScrollView] contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[ascii enclosingScrollView] contentView]];
	
	// finally, show the window
	[self showWindow:self];
}
/*
- (BOOL)windowShouldClose:(NSWindow *)sender
{
	return [sender isDocumentEdited];
}*/

- (IBAction)showFind:(id)sender
{
	// bug: HexWindowController allocs a sheet controller, but it's never disposed of
	FindSheetController *sheetController = [[FindSheetController alloc] initWithWindowNibName:@"FindSheet"];
	[sheetController showFindSheet:self];
}

- (void)viewDidScroll:(NSNotification *)notification
{
	// get object refs for increased speed
	NSClipView *object		= (NSClipView *) [notification object];
	NSClipView *offsetClip	= [[offset enclosingScrollView] contentView];
	NSClipView *hexClip		= [[hex enclosingScrollView] contentView];
	NSClipView *asciiClip	= [[ascii enclosingScrollView] contentView];
	
	// due to a bug in -[NSView setPostsBoundsChangedNotifications:] (it basically doesn't work), I am having to work around it by removing myself from the notification center and restoring things later on!
	// update, Apple say this isn't their bug.
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

- (void)resourceNameDidChange:(NSNotification *)notification
{
	if( ![[(id <ResKnifeResourceProtocol>)[notification object] name] isEqualToString:@""] )
		[[self window] setTitle:[(id <ResKnifeResourceProtocol>)[notification object] name]];
	else [[self window] setTitle:NSLocalizedStringFromTableInBundle(@"Untitled Resource", @"Localizable", [NSBundle mainBundle], nil)];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for other resource notifications)
	if( [notification object] == (id)resource )
		[self refreshData:[resource data]];
}

- (void)refreshData:(NSData *)data;
{
	NSDictionary *dictionary;
	NSMutableParagraphStyle *paragraph = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	// save selections
	NSRange hexSelection = [hex selectedRange];
	NSRange asciiSelection = [ascii selectedRange];
	
	// clear delegates (see HexEditorDelegate class for explanation of why)
	id oldDelegate = [hex delegate];
	[hex setDelegate:nil];
	[ascii setDelegate:nil];
	
	// prepare attributes dictionary
	[paragraph setLineBreakMode:NSLineBreakByCharWrapping];
	dictionary = [NSDictionary dictionaryWithObject:paragraph forKey:NSParagraphStyleAttributeName];
	
	// do stuff with data
	[offset	setString:[hexDelegate offsetRepresentation:data]];
	[hex	setString:[hexDelegate hexRepresentation:data]];
	[ascii	setString:[hexDelegate asciiRepresentation:data]];
	
	// apply attributes
	[[offset textStorage] addAttributes:dictionary range:NSMakeRange(0, [[offset textStorage] length])];
	[[hex	 textStorage] addAttributes:dictionary range:NSMakeRange(0, [[hex textStorage] length])];
	[[ascii	 textStorage] addAttributes:dictionary range:NSMakeRange(0, [[ascii textStorage] length])];
	
	// restore selections (this is the dumbest way to do it, but it'll do for now)
	[hex setSelectedRange:NSIntersectionRange(hexSelection, [hex selectedRange])];
	[ascii setSelectedRange:NSIntersectionRange(asciiSelection, [ascii selectedRange])];
	
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

- (int)bytesPerRow
{
	return bytesPerRow;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undoManager;
}

@end