#import "ResourceDocument.h"
#import "Resource.h"
#import "ResourceNameCell.h"
#import "CreateResourceSheetController.h"

#import "ResKnifePluginProtocol.h"

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
#pragma mark -

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"ResourceDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
	[super windowControllerDidLoadNib:controller];
	[self setupToolbar:controller];
	
	{	// set up first column in outline view to display images as well as text
		ResourceNameCell *resourceNameCell = [[[ResourceNameCell alloc] init] autorelease];
		[resourceNameCell setEditable:YES];
		[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:resourceNameCell];
	}
	
//	[[controller window] setResizeIncrements:NSMakeSize(1,18)];
//	[controller setDocumet:self];
	[dataSource setResources:resources];
}

- (BOOL)keepBackupFile
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"PreserveBackups"];
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
	NSString *file = [[[sender representedFilename] lastPathComponent] stringByDeletingPathExtension];
	if( [file isEqualToString:@""] ) file = @"this document";
	NSBeginAlertSheet( @"Save Document?", @"Save", @"Don’t Save", @"Cancel", sender, self, @selector(didEndShouldCloseSheet:returnCode:contextInfo:), NULL, sender, @"Do you wish to save %@?", file );
	return NO;
}

- (void)didEndShouldCloseSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if( returnCode == NSAlertDefaultReturn )		// save then close
	{
		[self saveDocument:contextInfo];
		[(NSWindow *)contextInfo close];
	}
	else if( returnCode == NSAlertAlternateReturn )	// don't save, just close
	{
		[(NSWindow *)contextInfo close];
	}
	else if( returnCode == NSAlertErrorReturn )
	{
		NSLog( @"didEndShouldCloseSheet received NSAlertErrorReturn return code" );
	}
	// else returnCode == NSAlertOtherReturn, cancel
}

/* TOOLBAR MANAGMENT */
#pragma mark -

static NSString *RKToolbarIdentifier		= @"com.nickshanks.resknife.toolbar";
static NSString *RKCreateItemIdentifier		= @"com.nickshanks.resknife.toolbar.create";
static NSString *RKDeleteItemIdentifier		= @"com.nickshanks.resknife.toolbar.delete";
static NSString *RKEditItemIdentifier		= @"com.nickshanks.resknife.toolbar.edit";
static NSString *RKEditHexItemIdentifier	= @"com.nickshanks.resknife.toolbar.edithex";
static NSString *RKSaveItemIdentifier		= @"com.nickshanks.resknife.toolbar.save";
static NSString *RKShowInfoItemIdentifier	= @"com.nickshanks.resknife.toolbar.showinfo";

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
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
	
	if( [itemIdentifier isEqual:RKCreateItemIdentifier] )
	{
		[item setLabel:@"Create"];
		[item setPaletteLabel:@"Create"];
		[item setToolTip:@"Create New Resource"];
		[item setImage:[NSImage imageNamed:@"Create"]];
		[item setTarget:self];
		[item setAction:@selector(showCreateResourceSheet:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKDeleteItemIdentifier] )
	{
		[item setLabel:@"Delete"];
		[item setPaletteLabel:@"Delete"];
		[item setToolTip:@"Delete Selected Resource"];
		[item setImage:[NSImage imageNamed:@"Delete"]];
		[item setTarget:outlineView];
		[item setAction:@selector(clear:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKEditItemIdentifier] )
	{
		[item setLabel:@"Edit"];
		[item setPaletteLabel:@"Edit"];
		[item setToolTip:@"Edit Resource In Default Editor"];
		[item setImage:[NSImage imageNamed:@"Edit"]];
		[item setTarget:self];
		[item setAction:@selector(openResource:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKEditHexItemIdentifier] )
	{
		[item setLabel:@"Edit Hex"];
		[item setPaletteLabel:@"Edit Hex"];
		[item setToolTip:@"Edit Resource As Hexadecimal"];
		[item setImage:[NSImage imageNamed:@"Edit Hex"]];
		[item setTarget:self];
		[item setAction:@selector(openResourceAsHex:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKSaveItemIdentifier] )
	{
		[item setLabel:@"Save"];
		[item setPaletteLabel:@"Save"];
		[item setToolTip:[NSString stringWithFormat:@"Save To %@ Fork", !otherFork? @"Data":@"Resource"]];
		[item setImage:[NSImage imageNamed:@"Save"]];
		[item setTarget:self];
		[item setAction:@selector(saveDocument:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKShowInfoItemIdentifier] )
	{
		[item setLabel:@"Show Info"];
		[item setPaletteLabel:@"Show Info"];
		[item setToolTip:@"Show Resource Information Window"];
		[item setImage:[NSImage imageNamed:@"Show Info"]];
		[item setTarget:[NSApp delegate]];
		[item setAction:@selector(showInfo:)];
		return item;
	}
	else return nil;

/*	if([itemIdent isEqual: SearchDocToolbarItemIdentifier]) {
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
    return toolbarItem;	*/
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKCreateItemIdentifier, RKEditItemIdentifier, RKEditHexItemIdentifier, NSToolbarSeparatorItemIdentifier, RKSaveItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKCreateItemIdentifier, RKDeleteItemIdentifier, RKEditItemIdentifier, RKEditHexItemIdentifier, RKSaveItemIdentifier, RKShowInfoItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)item
{
	BOOL valid = NO;
	NSString *identifier = [item itemIdentifier];
	
	if( [identifier isEqual:RKCreateItemIdentifier] )				valid = YES;
//	else if( [identifier isEqual:RKDeleteItemIdentifier] )			valid = [outlineView numberOfSelectedRows]? YES:NO;
	else if( [identifier isEqual:RKEditItemIdentifier] )			valid = NO;
	else if( [identifier isEqual:RKEditHexItemIdentifier] )			valid = [outlineView numberOfSelectedRows]? YES:NO;
	else if( [identifier isEqual:RKSaveItemIdentifier] )			valid = [self isDocumentEdited];
	else if( [identifier isEqual:NSToolbarPrintItemIdentifier] )	valid = YES;
	
	return valid;
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
*/

/* DOCUMENT MANAGEMENT */
#pragma mark -

- (IBAction)showCreateResourceSheet:(id)sender
{
	[[dataSource createResourceSheetController] showCreateResourceSheet:self];
}

- (IBAction)openResource:(id)sender
{
	if( NO );
	else [self openResourceAsHex:sender];
}

- (IBAction)openResourceAsHex:(id)sender
{
	NSBundle *hexEditor = [NSBundle bundleWithPath:[[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent:@"Hexadecimal Editor.plugin"]];
	Resource *resource = [outlineView itemAtRow:[outlineView selectedRow]];
	// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
	[(id <ResKnifePluginProtocol>)[[hexEditor principalClass] alloc] initWithResource:resource];
}

- (IBAction)playSound:(id)sender
{
	Resource *resource = [outlineView itemAtRow:[outlineView selectedRow]];
	NSSound *sound = [[NSSound alloc] initWithData:[resource data]];
	[sound setDelegate:self];
	[sound play];
}

- (void)sound:(NSSound *)sound didFinishPlaying:(BOOL)finished
{
	if( finished ) [sound release];
	NSLog( @"sound released" );
}

/* FILE HANDLING */
#pragma mark -

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
#pragma mark -

- (NSOutlineView *)outlineView
{
	return outlineView;
}

- (ResourceDataSource *)dataSource
{
	return dataSource;
}

- (NSArray *)resources
{
	return resources;
}

@end