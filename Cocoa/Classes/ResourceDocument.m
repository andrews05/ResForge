#import "ResourceDocument.h"
#import "Resource.h"

@implementation ResourceDocument

- (id)init
{
	self = [super init];
	resources = [[NSMutableArray alloc] init];
	otherFork = nil;
	return self;
}

- (void)dealloc
{
	if( otherFork )
		DisposePtr( (Ptr) otherFork );
	[resources release];
	[super dealloc];
}

/* WINDOW DELEGATION */

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"ResourceDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
    [super windowControllerDidLoadNib:controller];
    // Add any code here that need to be executed once the windowController has loaded the document's window.
	[self setupToolbar:controller];
//	[controller setDocumet:self];
	[dataSource setResources:resources];
}

- (BOOL)keepBackupFile
{
	return NO;		// return whatever the user preference is for this! (NSDefaults)
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
	NSString *file = [[[sender representedFilename] lastPathComponent] stringByDeletingPathExtension];
	if( [file isEqualToString:@""] ) file = @"this document";
	NSBeginAlertSheet( @"Save Document?", @"Save", @"Cancel", @"Don’t Save", sender, self, @selector(didEndShouldCloseSheet:returnCode:contextInfo:), NULL, sender, @"Do you wish to save %@?", file );
	return NO;
}

- (void)didEndShouldCloseSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if( returnCode == NSAlertDefaultReturn )		// save then close
	{
		[self saveDocument:contextInfo];
		[(NSWindow *)contextInfo close];
	}
	else if( returnCode == NSAlertOtherReturn )		// don't save, just close
	{
		[(NSWindow *)contextInfo close];
	}
	else if( returnCode == NSAlertErrorReturn )
	{
		NSLog( @"didEndShouldCloseSheet received NSAlertErrorReturn return code" );
	}
	// else returnCode == NSAlertAlternateReturn, cancel
}

/* TOOLBAR MANAGMENT */

static NSString *RKToolbarIdentifier = @"com.nickshanks.resknife.toolbar";
static NSString *RKSaveItemIdentifier = @"com.nickshanks.resknife.toolbar.save";

- (void)setupToolbar:(NSWindowController *)controller
{
	/* This routine should become invalid once toolbars are integrated into nib files */
	
	NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:RKToolbarIdentifier] autorelease];
	
	// set toolbar properties
	[toolbar setVisible:NO];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeDefault];
	
	// attach toolbar to window 
	[toolbar setDelegate:self];
	[[controller window] setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	if( [itemIdentifier isEqual:RKSaveItemIdentifier] )
	{
		NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
		[item setLabel:@"Save"];
		[item setPaletteLabel:@"Save"];
		[item setToolTip:[NSString stringWithFormat:@"Save To %@ Fork", saveToDataFork? @"Data":@"Resource"]];
		[item setImage:[NSImage imageNamed:@"Save"]];
		[item setTarget:self];
		[item setAction:@selector(saveDocument:)];
		return item;
	}
	else return nil;
/*    // Required delegate method   Given an item identifier, self method returns an item 
    // The toolbar will use self method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    if ([itemIdent isEqual: SaveDocToolbarItemIdentifier]) {
	// Set the text label to be displayed in the toolbar and customization palette 
	[toolbarItem setLabel: @"Save"];
	[toolbarItem setPaletteLabel: @"Save"];
	
	// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
	[toolbarItem setToolTip: @"Save Your Document"];
	[toolbarItem setImage: [NSImage imageNamed: @"SaveDocumentItemImage"]];
	
	// Tell the item what message to send when it is clicked 
	[toolbarItem setTarget: self];
	[toolbarItem setAction: @selector(saveDocument:)];
    } else if([itemIdent isEqual: SearchDocToolbarItemIdentifier]) {
	NSMenu *submenu = nil;
	NSMenuItem *submenuItem = nil, *menuFormRep = nil;
	
	// Set up the standard properties 
	[toolbarItem setLabel: @"Search"];
	[toolbarItem setPaletteLabel: @"Search"];
	[toolbarItem setToolTip: @"Search Your Document"];
	
	// Use a custom view, a text field, for the search item 
	[toolbarItem setView: searchFieldOutlet];
	[toolbarItem setMinSize:NSMakeSize(30, NSHeight([searchFieldOutlet frame]))];
	[toolbarItem setMaxSize:NSMakeSize(400,NSHeight([searchFieldOutlet frame]))];

	// By default, in text only mode, a custom items label will be shown as disabled text, but you can provide a 
	// custom menu of your own by using <item> setMenuFormRepresentation] 
	submenu = [[[NSMenu alloc] init] autorelease];
	submenuItem = [[[NSMenuItem alloc] initWithTitle: @"Search Panel" action: @selector(searchUsingSearchPanel:) keyEquivalent: @""] autorelease];
	menuFormRep = [[[NSMenuItem alloc] init] autorelease];

	[submenu addItem: submenuItem];
	[submenuItem setTarget: self];
	[menuFormRep setSubmenu: submenu];
	[menuFormRep setTitle: [toolbarItem label]];
	[toolbarItem setMenuFormRepresentation: menuFormRep];
    } else {
	// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
	// Returning nil will inform the toolbar self kind of item is not supported 
	toolbarItem = nil;
    }
    return toolbarItem;*/
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKSaveItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKSaveItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}
/*
- (void) toolbarWillAddItem: (NSNotification *) notif {
    // Optional delegate method   Before an new item is added to the toolbar, self notification is posted   
    // self is the best place to notice a new item is going into the toolbar   For instance, if you need to 
    // cache a reference to the toolbar item or need to set up some initial state, self is the best place 
    // to do it    The notification object is the toolbar to which the item is being added   The item being 
    // added is found by referencing the @"item" key in the userInfo 
    NSToolbarItem *addedItem = [[notif userInfo] objectForKey: @"item"];
    if([[addedItem itemIdentifier] isEqual: SearchDocToolbarItemIdentifier]) {
	activeSearchItem = [addedItem retain];
	[activeSearchItem setTarget: self];
	[activeSearchItem setAction: @selector(searchUsingToolbarTextField:)];
    } else if ([[addedItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
	[addedItem setToolTip: @"Print Your Document"];
	[addedItem setTarget: self];
    }
}  

- (void) toolbarDidRemoveItem: (NSNotification *) notif {
    // Optional delegate method   After an item is removed from a toolbar the notification is sent   self allows 
    // the chance to tear down information related to the item that may have been cached   The notification object
    // is the toolbar to which the item is being added   The item being added is found by referencing the @"item"
    // key in the userInfo 
    NSToolbarItem *removedItem = [[notif userInfo] objectForKey: @"item"];
    if (removedItem==activeSearchItem) {
	[activeSearchItem autorelease];
	activeSearchItem = nil;    
    }
}

- (BOOL) validateToolbarItem: (NSToolbarItem *) toolbarItem {
    // Optional method   self message is sent to us since we are the target of some toolbar item actions 
    // (for example:  of the save items action) 
    BOOL enable = NO;
    if ([[toolbarItem itemIdentifier] isEqual: SaveDocToolbarItemIdentifier]) {
	// We will return YES (ie  the button is enabled) only when the document is dirty and needs saving 
	enable = [self isDocumentEdited];
    } else if ([[toolbarItem itemIdentifier] isEqual: NSToolbarPrintItemIdentifier]) {
	enable = YES;
    }	
    return enable;
}*/

/* FILE HANDLING */

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
	BOOL succeeded = NO;
	OSStatus error = noErr;
	HFSUniStr255 *resourceForkName = (HFSUniStr255 *) NewPtrClear( sizeof(HFSUniStr255) );
	FSRef *fileRef = (FSRef *) NewPtrClear( sizeof(FSRef) );
	SInt16 fileRefNum = 0;
	
	// open fork with resources in it
	error = FSPathMakeRef( [fileName cString], fileRef, nil );
	error = FSGetResourceForkName( resourceForkName );
	SetResLoad( false );	// don't load "preload" resources
	error = FSOpenResourceFile( fileRef, resourceForkName->length, (UniChar *) &resourceForkName->unicode, fsRdPerm, &fileRefNum);
	if( error )				// try to open data fork instead
		error = FSOpenResourceFile( fileRef, 0, nil, fsRdPerm, &fileRefNum);
	else otherFork = resourceForkName;
	SetResLoad( true );		// restore resource loading as soon as is possible
	
	// read the resources
	if( fileRefNum && !error )
		succeeded = [self readResourceMap:fileRefNum];
	
	// tidy up loose ends
	if( !otherFork ) DisposePtr( (Ptr) resourceForkName );	// only delete if we're not saving it
	if( fileRefNum ) FSClose( fileRefNum );
	DisposePtr( (Ptr) fileRef );
	return succeeded;
}

- (BOOL)readResourceMap:(SInt16)fileRefNum
{
	OSStatus error = noErr;
	unsigned short i, j, n;
	SInt16 oldResFile = CurResFile();
	UseResFile( fileRefNum );
	
	for( i = 1; i <= Count1Types(); i++ )
	{
		ResType resType;
		Get1IndType( &resType, i );
		n = Count1Resources( resType );
		for( j = 1; j <= n; j++ )
		{
			Str255	nameStr;
			long	sizeLong;
			short	resIDShort;
			short	attrsShort;
			Handle	resourceHandle;
			
			resourceHandle = Get1IndResource( resType, j );
			error = ResError();
			if( error != noErr )
			{
				UseResFile( oldResFile );
				return NO;
			}
			
			GetResInfo( resourceHandle, &resIDShort, &resType, nameStr );
			sizeLong = GetResourceSizeOnDisk( resourceHandle );
			attrsShort = GetResAttrs( resourceHandle );
			HLockHi( resourceHandle );
			
			// create the resource & add it to the array
			{
				NSString	*name		= [NSString stringWithCString:&nameStr[1] length:nameStr[0]];
				NSString	*type		= [NSString stringWithCString:(char *) &resType length:4];
				NSNumber	*size		= [NSNumber numberWithLong:sizeLong];
				NSNumber	*resID		= [NSNumber numberWithShort:resIDShort];
				NSNumber	*attributes	= [NSNumber numberWithShort:attrsShort];
				NSData		*data		= [NSData dataWithBytes:*resourceHandle length:sizeLong];
				Resource	*resource	= [Resource resourceOfType:type andID:resID withName:name andAttributes:attributes data:data ofLength:size];
				[resources addObject:resource];		// array retains resource
			}
			
			HUnlock( resourceHandle );
			ReleaseResource( resourceHandle );
		}
	}
	
	// save resource map and clean up
	UseResFile( oldResFile );
	return YES;
}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type
{
	BOOL succeeded = NO;
	OSStatus error = noErr;
	FSRef *parentRef	= (FSRef *) NewPtrClear( sizeof(FSRef) );
	FSRef *fileRef		= (FSRef *) NewPtrClear( sizeof(FSRef) );
	FSSpec *fileSpec	= (FSSpec *) NewPtrClear( sizeof(FSSpec) );
	SInt16 fileRefNum = 0;
	
	// create and open file for writing
	error = FSPathMakeRef( [[fileName stringByDeletingLastPathComponent] cString], parentRef, nil );
 	if( otherFork )
	{
		unichar *uniname = (unichar *) NewPtrClear( sizeof(unichar) *256 );
		[[fileName lastPathComponent] getCharacters:uniname];
		error = FSCreateResourceFile( parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, nil, otherFork->length, (UniChar *) &otherFork->unicode, fileRef, fileSpec );
		if( !error )
			error = FSOpenResourceFile( fileRef, otherFork->length, (UniChar *) &otherFork->unicode, fsWrPerm, &fileRefNum);
	}
	else
	{
		unichar *uniname = (unichar *) NewPtrClear( sizeof(unichar) *256 );
		[[fileName lastPathComponent] getCharacters:uniname];
		error = FSCreateResourceFile( parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, nil, 0, nil, fileRef, fileSpec );
		if( !error )
			error = FSOpenResourceFile( fileRef, 0, nil, fsWrPerm, &fileRefNum);
	}
	
	// write resource array to file
	if( fileRefNum && !error )
		succeeded = [self writeResourceMap:fileRefNum];
	
	// tidy up loose ends
	if( fileRefNum ) FSClose( fileRefNum );
	DisposePtr( (Ptr) fileRef );
	return succeeded;
}

- (BOOL)writeResourceMap:(SInt16)fileRefNum
{
	OSStatus error = noErr;
	unsigned long i;
	SInt16 oldResFile = CurResFile();
	UseResFile( fileRefNum );
	
	for( i = 0; i < [resources count]; i++ )
	{
		Resource *resource	= [resources objectAtIndex:i];
		
		Str255	nameStr;
		ResType	resType;
		short	resIDShort	= [[resource resID] shortValue];
		long	sizeLong	= [[resource size] longValue];
		short	attrsShort	= [[resource attributes] shortValue];
		Handle resourceHandle = NewHandleClear( sizeLong );
		
		nameStr[0] = [[resource name] cStringLength];
		BlockMoveData( [[resource name] cString], &nameStr[1], nameStr[0] );
		
		[[resource type] getCString:(char *) &resType maxLength:4];
		
		HLockHi( resourceHandle );
		[[resource data] getBytes:*resourceHandle];
		HUnlock( resourceHandle );
		
		AddResource( resourceHandle, resType, resIDShort, nameStr );
		if( ResError() == addResFailed )
		{
			NSLog( @"*Saving failed*; could not add resource \"%@\" of type %@ to file.", [resource name], [resource type] );
			error = addResFailed;
		}
		else
		{
			NSLog( @"Added resource %@, \"%@\", of type %@ to file.", [resource resID], [resource name], [resource type] );
			SetResAttrs( resourceHandle, attrsShort );
			ChangedResource( resourceHandle );
			UpdateResFile( fileRefNum );
		}
	}
	
	// save resource map and clean up
	UseResFile( oldResFile );
	return error? NO:YES;
}

/* ACCESSORS */

- (NSOutlineView *)outlineView
{
	return outlineView;
}

- (ResourceDataSource *)dataSource
{
	return dataSource;
}

@end