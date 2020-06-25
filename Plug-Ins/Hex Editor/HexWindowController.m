#import "HexWindowController.h"
#import "FindSheetController.h"

/*
OSStatus Plug_InitInstance(Plug_PlugInRef plug, Plug_ResourceRef resource)
{
	// init function called by carbon apps
	if(NSApplicationLoad())
	{
		id newResource = [NSClassFromString(@"Resource") resourceOfType:[NSString stringWithCString:length:4] andID:[NSNumber numberWithInt:] withName:[NSString stringWithCString:length:] andAttributes:[NSNumber numberWithUnsignedShort:] data:[NSData dataWithBytes:length:]];
		if(!newResource) return paramErr;
		id windowController = [[HexWindowController alloc] initWithResource:newResource];
		if(!windowController) return paramErr;
		else return noErr;
	}
	else return paramErr;
}
*/

@implementation HexWindowController
@synthesize textView;
@synthesize resource;

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
{
	self = [self initWithWindowNibName:@"HexWindow"];
	if(!self) return nil;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	undoManager = [[NSUndoManager alloc] init];
    resource = newResource;
	
	// load the window from the nib file
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
	
	// here because we don't want these notifications until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
    
    HFLineCountingRepresenter *lineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
    HFStatusBarRepresenter *statusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
    
    [[textView layoutRepresenter] addRepresenter:lineCountingRepresenter];
    [[textView layoutRepresenter] addRepresenter:statusBarRepresenter];
    // bug: lineCountingRepresenter doesn't correctly adjust for the nicer font
    //[[textView controller] setFont:[NSFont userFixedPitchFontOfSize:10.0]];
    [[textView controller] addRepresenter:lineCountingRepresenter];
    [[textView controller] addRepresenter:statusBarRepresenter];
    textView.data = resource.data;
    textView.delegate = self;
    [lineCountingRepresenter cycleLineNumberFormat];
    [[textView controller] setUndoManager:undoManager];
	
	// finally, set the window title & show the window
	[[self window] setTitle:[resource defaultWindowTitle]];
	[self showWindow:self];
	[[textView layoutRepresenter] performLayout];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [resource defaultWindowTitle];
}

- (BOOL)windowShouldClose:(id)sender
{
	if (self.window.documentEdited) {
		NSAlert *alert = [NSAlert new];
		alert.messageText = @"Do you want to keep the changes you made to this resource?";
		alert.informativeText = @"Your changes cannot be saved later if you don't keep them.";
		[alert addButtonWithTitle:@"Keep"];
		[alert addButtonWithTitle:@"Don't Keep"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			switch (returnCode) {
				case NSAlertFirstButtonReturn:	// keep
					[self saveResource:nil];
					[self.window close];
					break;
				
				case NSAlertSecondButtonReturn:	// don't keep
					[self.window close];
					break;
				
				case NSModalResponseCancel:		// cancel
					break;
			}
		}];
		return NO;
	}
	return YES;
}

- (void)saveResource:(id)sender
{
    [resource setData:[textView.data copy]];
}

- (void)revertResource:(id)sender
{
    textView.data = resource.data;
    [self setDocumentEdited:NO];
}

- (void)showFind:(id)sender
{
	if (!sheetController)
		sheetController = [[FindSheetController alloc] initWithWindowNibName:@"FindSheet"];
	[sheetController showFindSheet:self];
}

- (void)resourceNameDidChange:(NSNotification *)notification
{
    [self.window setTitle:[resource defaultWindowTitle]];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// TODO: we need to ask the user whether to accept the changes from the other editor and discard our changes, or vice versa.
    textView.data = resource.data;
    [self setDocumentEdited:NO];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undoManager;
}

- (void)hexTextView:(HFTextView *)view didChangeProperties:(HFControllerPropertyBits)properties {
    if (properties & HFControllerContentValue)
        [self setDocumentEdited:YES];
}

@end
