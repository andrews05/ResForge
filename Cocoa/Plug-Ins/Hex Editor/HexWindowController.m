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

- (instancetype)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"HexWindow"];
	if(!self) return nil;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	undoManager = [[NSUndoManager alloc] init];
	liveEdit = NO;
	if(liveEdit)
	{
		resource = newResource;	// resource to work on and monitor for external changes
		backup = [newResource copy];		// for reverting only
	}
	else
	{
		resource = [newResource copy];		// resource to work on
		backup = newResource;		// actual resource to change when saving data and monitor for external changes
	}
	
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
	if(liveEdit)	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceWasSaved:) name:ResourceDataDidChangeNotification object:resource];
    else			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceWasSaved:) name:ResourceDataDidChangeNotification object:backup];
    
    HFLineCountingRepresenter *lineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
    HFStatusBarRepresenter *statusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
    
    [[textView layoutRepresenter] addRepresenter:lineCountingRepresenter];
    [[textView layoutRepresenter] addRepresenter:statusBarRepresenter];
    // bug: lineCountingRepresenter doesn't correctly adjust for the nicer font
    //[[textView controller] setFont:[NSFont userFixedPitchFontOfSize:10.0]];
    [[textView controller] addRepresenter:lineCountingRepresenter];
    [[textView controller] addRepresenter:statusBarRepresenter];
    [textView bind:@"data" toObject:self withKeyPath:@"data" options:nil];
    [lineCountingRepresenter cycleLineNumberFormat];
	
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
	if([[self window] isDocumentEdited])
	{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:NSLocalizedStringFromTableInBundle(@"KeepChangesDialogTitle", nil, bundle, nil)];
		[alert setInformativeText:NSLocalizedStringFromTableInBundle(@"KeepChangesDialogMessage", nil, bundle, nil)];
		[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"KeepChangesButton", nil, bundle, nil)];
		[alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"CancelButton", nil, bundle, nil)];
		NSButton *button = [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"DiscardChangesButton", nil, bundle, nil)];
		[button setKeyEquivalent:@"d"];
		[button setKeyEquivalentModifierMask:NSCommandKeyMask];
		[alert beginSheetModalForWindow:sender modalDelegate:self didEndSelector:@selector(saveSheetDidClose:returnCode:contextInfo:) contextInfo:NULL];
		//[alert release];
		return NO;
	}
	else return YES;
}

- (void)saveSheetDidClose:(NSAlert *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	switch (returnCode) {
		case NSAlertFirstButtonReturn:		// keep
			[self saveResource:nil];
			[[self window] close];
			break;
		
		case NSAlertSecondButtonReturn:	// cancel
			break;
		
		case NSAlertThirdButtonReturn:		// don't keep
		default:
			[[sheet window] orderOut:nil];
			[[self window] close];
			break;
	}
}

- (void)saveResource:(id)sender
{
	[backup setData:[[resource data] copy]];
}

- (void)revertResource:(id)sender
{
	[resource setData:[[backup data] copy]];
}

- (void)showFind:(id)sender
{
	// bug: HexWindowController allocs a sheet controller, but it's never disposed of
	if (!sheetController)
		sheetController = [[FindSheetController alloc] initWithWindowNibName:@"FindSheet"];
	[sheetController showFindSheet:self];
}

- (void)resourceNameDidChange:(NSNotification *)notification
{
	[[self window] setTitle:[(id <ResKnifeResource>)[notification object] defaultWindowTitle]];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	// ensure it's our resource which got changed (should always be true, we don't register for other resource notifications)
	// bug: if liveEdit is false and another editor changes backup, if we are dirty we need to ask the user whether to accept the changes from the other editor and discard our changes, or vice versa.
	if([notification object] == (id)resource)
	{
		[self setDocumentEdited:YES];
	}
}

- (void)resourceWasSaved:(NSNotification *)notification
{
	id <ResKnifeResource> object = [notification object];
	if(liveEdit)
	{
		// haven't worked out what to do here yet
	}
	else
	{
		// this should refresh the view automatically
		[resource setData:[[object data] copy]];
		[self setDocumentEdited:NO];
	}
}

- (id)resource
{
	return resource;
}

- (NSData *)data
{
	return resource.data;
}

- (void)setData:(NSData *)data
{
	resource.data = data;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undoManager;
}

@end
