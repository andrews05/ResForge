#import "HexWindowController.h"
#import "FindSheetController.h"

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

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// here because we don't want these notifications until we have a window! (Only register for notifications on the resource we're editing)
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
    
    HFLineCountingRepresenter *lineCountingRepresenter = [HFLineCountingRepresenter new];
    HFStatusBarRepresenter *statusBarRepresenter = [HFStatusBarRepresenter new];
    
    [textView.layoutRepresenter addRepresenter:lineCountingRepresenter];
    [textView.layoutRepresenter addRepresenter:statusBarRepresenter];
    [textView.controller setFont:[NSFont userFixedPitchFontOfSize:10.0]];
    [textView.controller addRepresenter:lineCountingRepresenter];
    [textView.controller addRepresenter:statusBarRepresenter];
    textView.data = resource.data;
    textView.delegate = self;
    [lineCountingRepresenter cycleLineNumberFormat];
    [textView.controller setUndoManager:undoManager];
	
	// finally, set the window title & show the window
    self.window.title = resource.defaultWindowTitle;
	[self showWindow:self];
	[textView.layoutRepresenter performLayout];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
    return resource.defaultWindowTitle;
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
    resource.data = [textView.data copy];
}

- (void)revertResource:(id)sender
{
    textView.data = resource.data;
    [self setDocumentEdited:NO];
}

- (IBAction)showFind:(id)sender
{
    [FindSheetController.shared showFindSheet:self.window];
}

- (IBAction)findNext:(id)sender
{
    [FindSheetController.shared findIn:textView.controller forwards:YES];
}

- (IBAction)findPrevious:(id)sender
{
    [FindSheetController.shared findIn:textView.controller forwards:NO];
}

- (IBAction)findWithSelection:(id)sender
{
    BOOL asHex = [self.window.firstResponder.className isEqualToString:@"HFRepresenterHexTextView"];
    [FindSheetController.shared setFindSelection:textView.controller asHex:asHex];
}

- (IBAction)scrollToSelection:(id)sender
{
    HFRange selection = [textView.controller.selectedContentsRanges[0] HFRange];
    [textView.controller maximizeVisibilityOfContentsRange:selection];
    [textView.controller pulseSelection];
}

- (void)resourceNameDidChange:(NSNotification *)notification
{
    [self.window setTitle:resource.defaultWindowTitle];
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
