#import "ResourceDocument.h"
#import "Resource.h"
#import "ResourceDataSource.h"
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
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
	
	// register for resource will change notifications (for undo management)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameWillChange:) name:ResourceNameWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceIDWillChange:) name:ResourceIDWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceTypeWillChange:) name:ResourceTypeWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceAttributesWillChange:) name:ResourceAttributesWillChangeNotification object:nil];
	
//	[[controller window] setResizeIncrements:NSMakeSize(1,18)];
//	[controller setDocumet:self];
	[dataSource setResources:resources];
}

- (BOOL)keepBackupFile
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"PreserveBackups"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	Resource *resource = (Resource *) [outlineView itemAtRow:[outlineView selectedRow]];
	if( [item action] == @selector(saveDocument:) )					return [self isDocumentEdited];
	else if( [item action] == @selector(openResource:) )			return ([outlineView numberOfSelectedRows] == 1)? YES:NO;
	else if( [item action] == @selector(openResourceAsHex:) )		return [outlineView numberOfSelectedRows]? YES:NO;
	else if( [item action] == @selector(playSound:) )				return [[resource type] isEqualToString:@"snd "];
	else if( [item action] == @selector(revertResourceToSaved:) )	return [resource isDirty];
	else return [super validateMenuItem:item];
}

/*
- (BOOL)windowShouldClose:(NSWindow *)sender
{
	if( [self isDocumentEdited] == NO ) return YES;
	
	// document has been modified, so display save dialog and defer close
	NSString *file = [[[sender representedFilename] lastPathComponent] stringByDeletingPathExtension];
	if( [file isEqualToString:@""] ) file = NSLocalizedString(@"this document", nil);
	NSBeginAlertSheet( NSLocalizedString(@"Save Document?", nil), NSLocalizedString(@"Save", nil), NSLocalizedString(@"Don’t Save", nil), NSLocalizedString(@"Cancel", nil), sender, self, @selector(didEndShouldCloseSheet:returnCode:contextInfo:), NULL, sender, NSLocalizedString(@"Do you wish to save %@?", nil), file );
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
}*/

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
		[item setLabel:NSLocalizedString(@"Create", nil)];
		[item setPaletteLabel:NSLocalizedString(@"Create", nil)];
		[item setToolTip:NSLocalizedString(@"Create New Resource", nil)];
		[item setImage:[NSImage imageNamed:@"Create"]];
		[item setTarget:self];
		[item setAction:@selector(showCreateResourceSheet:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKDeleteItemIdentifier] )
	{
		[item setLabel:NSLocalizedString(@"Delete", nil)];
		[item setPaletteLabel:NSLocalizedString(@"Delete", nil)];
		[item setToolTip:NSLocalizedString(@"Delete Selected Resource", nil)];
		[item setImage:[NSImage imageNamed:@"Delete"]];
		[item setTarget:self];
		[item setAction:@selector(clear:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKEditItemIdentifier] )
	{
		[item setLabel:NSLocalizedString(@"Edit", nil)];
		[item setPaletteLabel:NSLocalizedString(@"Edit", nil)];
		[item setToolTip:NSLocalizedString(@"Edit Resource In Default Editor", nil)];
		[item setImage:[NSImage imageNamed:@"Edit"]];
		[item setTarget:self];
		[item setAction:@selector(openResource:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKEditHexItemIdentifier] )
	{
		[item setLabel:NSLocalizedString(@"Edit Hex", nil)];
		[item setPaletteLabel:NSLocalizedString(@"Edit Hex", nil)];
		[item setToolTip:NSLocalizedString(@"Edit Resource As Hexadecimal", nil)];
		[item setImage:[NSImage imageNamed:@"Edit Hex"]];
		[item setTarget:self];
		[item setAction:@selector(openResourceAsHex:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKSaveItemIdentifier] )
	{
		[item setLabel:NSLocalizedString(@"Save", nil)];
		[item setPaletteLabel:NSLocalizedString(@"Save", nil)];
		[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Save To %@ Fork", nil), !otherFork? NSLocalizedString(@"Data", nil) : NSLocalizedString(@"Resource", nil)]];
		[item setImage:[NSImage imageNamed:@"Save"]];
		[item setTarget:self];
		[item setAction:@selector(saveDocument:)];
		return item;
	}
	else if( [itemIdentifier isEqual:RKShowInfoItemIdentifier] )
	{
		[item setLabel:NSLocalizedString(@"Show Info", nil)];
		[item setPaletteLabel:NSLocalizedString(@"Show Info", nil)];
		[item setToolTip:NSLocalizedString(@"Show Resource Information Window", nil)];
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
	int selection = [outlineView numberOfSelectedRows];
	NSString *identifier = [item itemIdentifier];
	
	if( [identifier isEqualToString:RKCreateItemIdentifier] )				valid = YES;
	else if( [identifier isEqualToString:RKDeleteItemIdentifier] )			valid = selection? YES:NO;
	else if( [identifier isEqualToString:RKEditItemIdentifier] )			valid = (selection == 1)? YES:NO;
	else if( [identifier isEqualToString:RKEditHexItemIdentifier] )			valid = selection? YES:NO;
	else if( [identifier isEqualToString:RKSaveItemIdentifier] )			valid = [self isDocumentEdited];
	else if( [identifier isEqualToString:NSToolbarPrintItemIdentifier] )	valid = YES;
	
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

- (void)resourceNameWillChange:(NSNotification *)notification
{
	// this saves the current resource's name so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setName:) object:[[[resource name] copy] autorelease]];
	[[self undoManager] setActionName:NSLocalizedString(@"Name Change", nil)];
}

- (void)resourceIDWillChange:(NSNotification *)notification
{
	// this saves the current resource's ID number so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setResID:) object:[[[resource resID] copy] autorelease]];
	if( [[resource name] length] == 0 )
		[[self undoManager] setActionName:NSLocalizedString(@"ID Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"ID Change for “%@”", nil), [resource name]]];
}

- (void)resourceTypeWillChange:(NSNotification *)notification
{
	// this saves the current resource's type so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setType:) object:[[[resource type] copy] autorelease]];
	if( [[resource name] length] == 0 )
		[[self undoManager] setActionName:NSLocalizedString(@"Type Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Type Change for “%@”", nil), [resource name]]];
}

- (void)resourceAttributesWillChange:(NSNotification *)notification
{
	// this saves the current state of the resource's attributes so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setAttributes:) object:[[[resource attributes] copy] autorelease]];
	if( [[resource name] length] == 0 )
		[[self undoManager] setActionName:NSLocalizedString(@"Attributes Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Attributes Change for “%@”", nil), [resource name]]];
}

/* EDIT OPERATIONS */
#pragma mark -

- (IBAction)clear:(id)sender
{
	NSNumber *row;
	Resource *resource;
	NSMutableArray *selectedObjects = [NSMutableArray array];
	NSEnumerator *enumerator = [outlineView selectedRowEnumerator];
	int selectedRows = [outlineView numberOfSelectedRows];
	
	// obtain array of selected resources
	[[self undoManager] beginUndoGrouping];
	while( row = [enumerator nextObject] )
	{
		[selectedObjects addObject:[outlineView itemAtRow:[row intValue]]];
	}
	
	// enumerate through array and delete resources
	//	i can't just delete resources above, because it screws with the enumeration!
	enumerator = [selectedObjects reverseObjectEnumerator];		// reverse so an undo will replace items in original order
	while( resource = [enumerator nextObject] )
	{
		[dataSource removeResource:resource];
		if( [[resource name] length] == 0 )
			[[self undoManager] setActionName:NSLocalizedString(@"Delete Resource", nil)];
		else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Delete Resource “%@”", nil), [resource name]]];
	}
	[[self undoManager] endUndoGrouping];
	
	// generalise undo name if more than one was deleted
	if( selectedRows > 1 )
		[[self undoManager] setActionName:NSLocalizedString(@"Delete Resources", nil)];
	
	// deselct resources (otherwise other resources move into selected rows!)
	[outlineView deselectAll:self];
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
				NSNumber	*resID		= [NSNumber numberWithShort:resIDShort];
				NSNumber	*attributes	= [NSNumber numberWithShort:attrsShort];
				NSData		*data		= [NSData dataWithBytes:*resourceHandle length:sizeLong];
				Resource	*resource	= [Resource resourceOfType:type andID:resID withName:name andAttributes:attributes data:data];
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
		short	attrsShort	= [[resource attributes] shortValue];
		Handle resourceHandle = NewHandleClear( [[resource data] length] );
		
		nameStr[0] = [[resource name] cStringLength];
		BlockMoveData( [[resource name] cString], &nameStr[1], nameStr[0] );
		
		[[resource type] getCString:(char *) &resType maxLength:4];
		
		HLockHi( resourceHandle );
		[[resource data] getBytes:*resourceHandle];
		HUnlock( resourceHandle );
		
		AddResource( resourceHandle, resType, resIDShort, nameStr );
		if( ResError() == addResFailed )
		{
			NSLog( @"*Saving failed*; could not add resource ID %@ of type %@ to file.", [resource resID], [resource type] );
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