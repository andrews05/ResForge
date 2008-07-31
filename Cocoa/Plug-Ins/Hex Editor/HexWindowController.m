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
	[super dealloc];
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	{
		// set up tab, shift-tab and enter behaviour (cannot set these in IB at the moment)
		[hex setFieldEditor:YES];
		[ascii setFieldEditor:YES];
		[offset setDrawsBackground:NO];
		[[offset enclosingScrollView] setDrawsBackground:NO];
		
		// IB fonts get ignored for some reason
		NSFont *courier = [[NSFontManager sharedFontManager] fontWithFamily:@"Courier" traits:0 weight:5 size:12.0];
		[hex setFont:courier];
		[ascii setFont:courier];
		[offset setFont:courier];
		
		// from HexEditorDelegate, here until bug is fixed
		[[NSNotificationCenter defaultCenter] addObserver:hexDelegate selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[offset enclosingScrollView] contentView]];
		[[NSNotificationCenter defaultCenter] addObserver:hexDelegate selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[hex enclosingScrollView] contentView]];
		[[NSNotificationCenter defaultCenter] addObserver:hexDelegate selector:@selector(viewDidScroll:) name:NSViewBoundsDidChangeNotification object:[[ascii enclosingScrollView] contentView]];
	}
	
	// insert the resources' data into the text fields
	[self refreshData:[resource data]];
	[[self window] setResizeIncrements:NSMakeSize(kWindowStepWidthPerChar * kWindowStepCharsPerStep * [[self window] userSpaceScaleFactor], 1)];
	// min 346, step 224, norm 570, step 224, max 794
	
	// here because we don't want these notifications until we have a window! (Only register for notifications on the resource we're editing)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameDidChange:) name:ResourceNameDidChangeNotification object:resource];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	if(liveEdit)	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceWasSaved:) name:ResourceDataDidChangeNotification object:resource];
	else			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceWasSaved:) name:ResourceDataDidChangeNotification object:backup];
	
	// finally, set the window title & show the window
	[[self window] setTitle:[resource defaultWindowTitle]];
	[self showWindow:self];
}

- (void)windowDidResize:(NSNotification *)notification
{
	float width = [[(NSWindow *)[notification object] contentView] frame].size.width;
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
		NSBeginAlertSheet(@"Do you want to keep the changes you made to this resource?", @"Keep", @"Don’t Keep", @"Cancel", sender, self, @selector(saveSheetDidClose:returnCode:contextInfo:), nil, nil, @"Your changes cannot be saved later if you don't keep them.");
		return NO;
	}
	else return YES;
}

- (void)saveSheetDidClose:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	switch(returnCode)
	{
		case NSAlertDefaultReturn:		// keep
			[self saveResource:nil];
			[[self window] close];
			break;
		
		case NSAlertAlternateReturn:	// don't keep
			[[self window] close];
			break;
		
		case NSAlertOtherReturn:		// cancel
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
	FindSheetController *sheetController = [[FindSheetController alloc] initWithWindowNibName:@"FindSheet"];
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
		[self refreshData:[resource data]];
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
		[resource setData:[[object data] copy]];
		[self setDocumentEdited:NO];
	}
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
	
	// prepare attributes dictionary
	NSMutableParagraphStyle *paragraph = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraph setLineBreakMode:NSLineBreakByCharWrapping];
	NSDictionary *dictionary = [NSDictionary dictionaryWithObject:paragraph forKey:NSParagraphStyleAttributeName];
	
	// do stuff with data
	[offset setString:[hexDelegate offsetRepresentation:data]];
	if([data length] > 0)
		[hex setString:[[data hexRepresentation] stringByAppendingString:@" "]];
	else [hex setString:[data hexRepresentation]];
	[ascii setString:[data asciiRepresentation]];
	
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