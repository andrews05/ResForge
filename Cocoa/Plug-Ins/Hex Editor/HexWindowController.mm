#import "HexWindowController.h"
#import "HexTextView.h"
#import "FindSheetController.h"
#import "NSData-HexRepresentation.h"

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

- (id)initWithResource:(id)newResource
{
	self = [self initWithWindowNibName:@"HexWindow"];
	if(!self) return nil;
	
	// one instance of your principal class will be created for every resource the user wants to edit (similar to Windows apps)
	undoManager = [[NSUndoManager alloc] init];
	liveEdit = NO;
	if(liveEdit)
	{
		resource = [newResource retain];	// resource to work on and monitor for external changes
		backup = [newResource copy];		// for reverting only
	}
	else
	{
		resource = [newResource copy];		// resource to work on
		backup = [newResource retain];		// actual resource to change when saving data and monitor for external changes
	}
	bytesPerRow = 16;
	
	// load the window from the nib file
	[self window];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[undoManager release];
	[(id)resource release];
	[sheetController release];
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// insert the resources' data into the text fields
	[[self window] setResizeIncrements:NSMakeSize(kWindowStepWidthPerChar * kWindowStepCharsPerStep, 1)];
	// min 346, step 224, norm 570, step 224, max 794
	
	// here because we don't want these notifications until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	if(liveEdit)	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceWasSaved:) name:ResourceDataDidChangeNotification object:resource];
	else			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceWasSaved:) name:ResourceDataDidChangeNotification object:backup];


	HFLineCountingRepresenter *lineCountingRepresenter = [[[HFLineCountingRepresenter alloc] init] autorelease];
	HFStatusBarRepresenter *statusBarRepresenter = [[[HFStatusBarRepresenter alloc] init] autorelease];
	
	[[textView layoutRepresenter] addRepresenter:lineCountingRepresenter];
	[[textView layoutRepresenter] addRepresenter:statusBarRepresenter];
	[[textView controller] setFont:[NSFont userFixedPitchFontOfSize:10.0]];
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

- (void)windowDidResize:(NSNotification *)notification
{
	int width = (int)[(NSWindow *)[notification object] frame].size.width;
	int oldBytesPerRow = bytesPerRow;
	bytesPerRow = (((width - (kWindowStepWidthPerChar * kWindowStepCharsPerStep) - 122) / (kWindowStepWidthPerChar * kWindowStepCharsPerStep)) + 1) * kWindowStepCharsPerStep;
	if(bytesPerRow != oldBytesPerRow)
		[offset	setString:[hexDelegate offsetRepresentation:[resource data]]];
	[[hex enclosingScrollView] setFrameSize:NSMakeSize((bytesPerRow * 21) + 5, [[hex enclosingScrollView] frame].size.height)];
	[[ascii enclosingScrollView] setFrameOrigin:NSMakePoint((bytesPerRow * 21) + 95, 20)];
	[[ascii enclosingScrollView] setFrameSize:NSMakeSize((bytesPerRow * 7) + 28, [[ascii enclosingScrollView] frame].size.height)];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu *editMenu = [[[NSApp mainMenu] itemAtIndex:2] submenu];
	NSMenuItem *copyItem = [editMenu itemAtIndex:[editMenu indexOfItemWithTarget:nil andAction:@selector(copy:)]];
	NSMenuItem *pasteItem = [editMenu itemAtIndex:[editMenu indexOfItemWithTarget:nil andAction:@selector(paste:)]];
	
	// swap copy: menu item for my own copy submenu
	[copyItem setEnabled:YES];
	[copyItem setKeyEquivalent:@"\0"];		// clear key equiv.
	[copyItem setKeyEquivalentModifierMask:0];
	[editMenu setSubmenu:copySubmenu forItem:copyItem];
	
	// swap paste: menu item for my own paste submenu
	[pasteItem setEnabled:YES];
	[pasteItem setKeyEquivalent:@"\0"];
	[pasteItem setKeyEquivalentModifierMask:0];
	[editMenu setSubmenu:pasteSubmenu forItem:pasteItem];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	NSMenu *editMenu = [[[NSApp mainMenu] itemAtIndex:2] submenu];
	NSMenuItem *copyItem = [editMenu itemAtIndex:[editMenu indexOfItemWithSubmenu:copySubmenu]];
	NSMenuItem *pasteItem = [editMenu itemAtIndex:[editMenu indexOfItemWithSubmenu:pasteSubmenu]];
	
	// swap my submenu for plain copy menu item
	[editMenu setSubmenu:nil forItem:copyItem];
	[copyItem setTarget:nil];
	[copyItem setAction:@selector(copy:)];
	[copyItem setKeyEquivalent:@"c"];
	[copyItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	
	// swap my submenu for plain paste menu item
	[editMenu setSubmenu:nil forItem:pasteItem];
	[pasteItem setTarget:nil];
	[pasteItem setAction:@selector(paste:)];
	[pasteItem setKeyEquivalent:@"v"];
	[pasteItem setKeyEquivalentModifierMask:NSCommandKeyMask];
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
	switch(returnCode)
	{
		case NSAlertFirstButtonReturn:		// keep
			[self saveResource:nil];
			[[self window] close];
			break;
		
		case NSAlertSecondButtonReturn:	// cancel
			break;
		
		case NSAlertThirdButtonReturn:		// don't keep
			[[sheet window] orderOut:nil];
			[[self window] close];
			break;
	}
}

- (void)saveResource:(id)sender
{
	[backup setData:[[[resource data] copy] autorelease]];
}

- (void)revertResource:(id)sender
{
	[resource setData:[[[backup data] copy] autorelease]];
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
	[[self window] setTitle:[(id <ResKnifeResourceProtocol>)[notification object] defaultWindowTitle]];
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
	id <ResKnifeResourceProtocol> object = [notification object];
	if(liveEdit)
	{
		// haven't worked out what to do here yet
	}
	else
	{
		// this should refresh the view automatically
		[resource setData:[[[object data] copy] autorelease]];
		[self setDocumentEdited:NO];
	}
}

- (id)resource
{
	return resource;
}

- (NSData *)data
{
	return [resource data];
}

- (void)setData:(NSData *)data {
	[resource setData:data];
}

- (int)bytesPerRow
{
	return bytesPerRow;
}

- (NSMenu *)copySubmenu
{
	return copySubmenu;
}

- (NSMenu *)pasteSubmenu
{
	return pasteSubmenu;
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)sender
{
	return undoManager;
}

/* range conversion methods */

+ (NSRange)byteRangeFromHexRange:(NSRange)hexRange
{
	// valid for all window widths
	NSRange byteRange = NSMakeRange(0,0);
	byteRange.location = (hexRange.location / 3);
	byteRange.length = (hexRange.length / 3) + ((hexRange.length % 3)? 1:0);
	return byteRange;
}

+ (NSRange)hexRangeFromByteRange:(NSRange)byteRange
{
	// valid for all window widths
	NSRange hexRange = NSMakeRange(0,0);
	hexRange.location = (byteRange.location * 3);
	hexRange.length = (byteRange.length * 3) - ((byteRange.length > 0)? 1:0);
	return hexRange;
}

+ (NSRange)byteRangeFromAsciiRange:(NSRange)asciiRange
{
	// one-to-one mapping
	return asciiRange;
}

+ (NSRange)asciiRangeFromByteRange:(NSRange)byteRange
{
	// one-to-one mapping
	return byteRange;
}

@end
