#import "HexWindowController.h"
#import "HexTextView.h"

@implementation HexWindowController

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
	resource = newResource;
	
	// load the window
//	[self setShouldCascadeWindows:YES];
	[self window];
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// set up text boxes (this doesn't do what I think it should!)
//	[hex setSelectionGranularity:NSSelectByWord];
	
	// insert the resources' data into the text fields
	[self refreshData:[(id <ResKnifeResourceProtocol>)resource data]];
	
	// finally, show the window
	[self showWindow:self];
}    

- (void)refreshData:(NSData *)data;
{
	// clear delegates (see HexEditorDelegate class for more info)
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

@end
