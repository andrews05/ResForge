#import "HexWindowController.h"
#import "HexTextView.h"

#import "ResKnifeResourceProtocol.h"

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
	if( self ) [self setWindowFrameAutosaveName:@"Hexadecimal Editor"];
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	resource = [newResource retain];
	
	// load the window
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
	
	// we don't want this notification until we have a window!
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDidChange:) name:ResourceChangedNotification object:nil];
	
	// insert the resources' data into the text fields
	[self refreshData:[(id <ResKnifeResourceProtocol>)resource data]];
	
	// finally, show the window
	[self showWindow:self];
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
