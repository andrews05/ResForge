#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "Resource.h"
#import "PrefsWindowController.h"
#import "CreateResourceSheetController.h"
#import "NSOutlineView-SelectedItems.h"

#import "ResKnifePluginProtocol.h"

NSString *DocumentInfoWillChangeNotification		= @"DocumentInfoWillChangeNotification";
NSString *DocumentInfoDidChangeNotification			= @"DocumentInfoDidChangeNotification";

@implementation ResourceDocument

- (id)init
{
	self = [super init];
	toolbarItems = [[NSMutableDictionary alloc] init];
	resources = [[NSMutableArray alloc] init];
	fork = nil;
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( fork ) DisposePtr( (Ptr) fork );
	[resources release];
	[toolbarItems release];
	[super dealloc];
}

/* WINDOW DELEGATION */
#pragma mark -

- (NSString *)windowNibName
{
    return @"ResourceDocument";
}

/*	This is not used, just here for reference in case I need it in the future

- (void)makeWindowControllers
{
	ResourceWindowController *resourceController = [[ResourceWindowController allocWithZone:[self zone]] initWithWindowNibName:@"ResourceDocument"];
    [self addWindowController:resourceController];
}*/

- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
	[super windowControllerDidLoadNib:controller];
	[self setupToolbar:controller];
	
	{	// set up first column in outline view to display images as well as text
		ResourceNameCell *resourceNameCell = [[[ResourceNameCell alloc] init] autorelease];
		[resourceNameCell setEditable:YES];
		[[outlineView tableColumnWithIdentifier:@"name"] setDataCell:resourceNameCell];
	}
	
	// set outline view's inter-cell psacing to zero to avoid getting gaps between blue bits
	[outlineView setIntercellSpacing:NSMakeSize(0,0)];
	
	// register for resource will change notifications (for undo management)
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceNameWillChange:) name:ResourceNameWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceIDWillChange:) name:ResourceIDWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceTypeWillChange:) name:ResourceTypeWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceAttributesWillChange:) name:ResourceAttributesWillChangeNotification object:nil];
	
//	[[controller window] setResizeIncrements:NSMakeSize(1,18)];
	[dataSource setResources:resources];
}

- (void)printShowingPrintPanel:(BOOL)flag
{
	NSPrintOperation *printOperation = [NSPrintOperation printOperationWithView:[mainWindow contentView]];
	[printOperation runOperationModalForWindow:mainWindow delegate:self didRunSelector:@selector(printOperationDidRun:success:contextInfo:) contextInfo:nil];
}

- (void)printOperationDidRun:(NSPrintOperation *)printOperation success:(BOOL)success contextInfo:(void *)contextInfo
{
	if( !success ) NSLog( @"Printing Failed!" );
}

- (BOOL)keepBackupFile
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"PreserveBackups"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	int selectedRows = [outlineView numberOfSelectedRows];
	Resource *resource = (Resource *) [outlineView selectedItem];
	
	// file menu
	if( [item action] == @selector(saveDocument:) )					return [self isDocumentEdited];
	
	// edit menu
	else if( [item action] == @selector(clear:) )					return selectedRows > 0;
	else if( [item action] == @selector(selectAll:) )				return [outlineView numberOfRows] > 0;
	else if( [item action] == @selector(deselectAll:) )				return selectedRows > 0;
	
	// resource menu
	else if( [item action] == @selector(openResources:) )			return selectedRows > 0;
	else if( [item action] == @selector(openResourcesInTemplate:) )	return selectedRows > 0;
	else if( [item action] == @selector(openResourcesWithOtherTemplate:) )	return selectedRows > 0;
	else if( [item action] == @selector(openResourcesAsHex:) )		return selectedRows > 0;
	else if( [item action] == @selector(playSound:) )				return selectedRows == 1 && [[resource type] isEqualToString:@"snd "];
	else if( [item action] == @selector(revertResourceToSaved:) )	return selectedRows == 1 && [resource isDirty];
	else return [super validateMenuItem:item];
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

- (void)setupToolbar:(NSWindowController *)windowController
{
	/* This routine should become invalid once toolbars are integrated into nib files */
	
	NSToolbarItem *item;
	[toolbarItems removeAllObjects];	// just in case this method is called more than once per document (which it shouldn't be!)
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKCreateItemIdentifier];
	[item setLabel:NSLocalizedString(@"Create", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Create", nil)];
	[item setToolTip:NSLocalizedString(@"Create New Resource", nil)];
	[item setImage:[NSImage imageNamed:@"Create"]];
	[item setTarget:self];
	[item setAction:@selector(showCreateResourceSheet:)];
	[toolbarItems setObject:item forKey:RKCreateItemIdentifier];
	[item release];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKDeleteItemIdentifier];
	[item setLabel:NSLocalizedString(@"Delete", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Delete", nil)];
	[item setToolTip:NSLocalizedString(@"Delete Selected Resource", nil)];
	[item setImage:[NSImage imageNamed:@"Delete"]];
	[item setTarget:self];
	[item setAction:@selector(clear:)];
	[toolbarItems setObject:item forKey:RKDeleteItemIdentifier];
	[item release];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKEditItemIdentifier];
	[item setLabel:NSLocalizedString(@"Edit", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Edit", nil)];
	[item setToolTip:NSLocalizedString(@"Edit Resource In Default Editor", nil)];
	[item setImage:[NSImage imageNamed:@"Edit"]];
	[item setTarget:self];
	[item setAction:@selector(openResources:)];
	[toolbarItems setObject:item forKey:RKEditItemIdentifier];
	[item release];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKEditHexItemIdentifier];
	[item setLabel:NSLocalizedString(@"Edit Hex", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Edit Hex", nil)];
	[item setToolTip:NSLocalizedString(@"Edit Resource As Hexadecimal", nil)];
	[item setImage:[NSImage imageNamed:@"Edit Hex"]];
	[item setTarget:self];
	[item setAction:@selector(openResourcesAsHex:)];
	[toolbarItems setObject:item forKey:RKEditHexItemIdentifier];
	[item release];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKSaveItemIdentifier];
	[item setLabel:NSLocalizedString(@"Save", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Save", nil)];
	[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Save To %@ Fork", nil), !fork? NSLocalizedString(@"Data", nil) : NSLocalizedString(@"Resource", nil)]];
	[item setImage:[NSImage imageNamed:@"Save"]];
	[item setTarget:self];
	[item setAction:@selector(saveDocument:)];
	[toolbarItems setObject:item forKey:RKSaveItemIdentifier];
	[item release];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKShowInfoItemIdentifier];
	[item setLabel:NSLocalizedString(@"Show Info", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Show Info", nil)];
	[item setToolTip:NSLocalizedString(@"Show Resource Information Window", nil)];
	[item setImage:[NSImage imageNamed:@"Show Info"]];
	[item setTarget:[NSApp delegate]];
	[item setAction:@selector(showInfo:)];
	[toolbarItems setObject:item forKey:RKShowInfoItemIdentifier];
	[item release];
	
	if( [windowController window] == mainWindow )
	{
		NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:RKToolbarIdentifier] autorelease];
		
		// set toolbar properties
		[toolbar setVisible:NO];
		[toolbar setAutosavesConfiguration:YES];
		[toolbar setAllowsUserCustomization:YES];
		[toolbar setDisplayMode:NSToolbarDisplayModeDefault];
		
		// attach toolbar to window
		[toolbar setDelegate:self];
		[mainWindow setToolbar:toolbar];
	}	
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [toolbarItems objectForKey:itemIdentifier];
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
	int selectedRows = [outlineView numberOfSelectedRows];
	NSString *identifier = [item itemIdentifier];
	
	if( [identifier isEqualToString:RKCreateItemIdentifier] )				valid = YES;
	else if( [identifier isEqualToString:RKDeleteItemIdentifier] )			valid = selectedRows > 0;
	else if( [identifier isEqualToString:RKEditItemIdentifier] )			valid = selectedRows > 0;
	else if( [identifier isEqualToString:RKEditHexItemIdentifier] )			valid = selectedRows > 0;
	else if( [identifier isEqualToString:RKSaveItemIdentifier] )			valid = [self isDocumentEdited];
	else if( [identifier isEqualToString:NSToolbarPrintItemIdentifier] )	valid = YES;
	
	return valid;
}

/* DOCUMENT MANAGEMENT */
#pragma mark -

- (IBAction)showCreateResourceSheet:(id)sender
{
	// bug: ResourceDocument allocs a sheet controller, but it's never disposed of
	CreateResourceSheetController *sheetController = [[CreateResourceSheetController alloc] initWithWindowNibName:@"CreateResourceSheet"];
	[sheetController showCreateResourceSheet:self];
}

- (IBAction)showSelectTemplateSheet:(id)sender
{
	// bug: ResourceDocument allocs a sheet controller, but it's never disposed of
//	SelectTemplateSheetController *sheetController = [[CreateResourceSheetController alloc] initWithWindowNibName:@"SelectTemplateSheet"];
//	[sheetController showSelectTemplateSheet:self];
}

- (IBAction)openResources:(id)sender
{
	Resource *resource;
	NSArray *selected = [outlineView selectedItems];
	NSEnumerator *enumerator = [selected objectEnumerator];
	while( resource = [enumerator nextObject] )
		[self openResourceUsingEditor:resource];
}

- (IBAction)openResourcesInTemplate:(id)sender
{
	// opens the resource in its default template
	Resource *resource;
	NSArray *selected = [outlineView selectedItems];
	NSEnumerator *enumerator = [selected objectEnumerator];
	while( resource = [enumerator nextObject] )
		[self openResource:resource usingTemplate:[resource type]];
}

- (IBAction)openResourcesAsHex:(id)sender
{
	Resource *resource;
	NSArray *selected = [outlineView selectedItems];
	NSEnumerator *enumerator = [selected objectEnumerator];
	while( resource = [enumerator nextObject] )
		[self openResourceAsHex:resource];
}

- (void)openResourceUsingEditor:(Resource *)resource
{
#warning openResourceUsingEditor: shortcuts to NovaTools !!
	// opens resource in template using TMPL resource with name templateName
	NSBundle *editor = [NSBundle bundleWithPath:[[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent:@"NovaTools.plugin"]];
	
	// open the resources, passing in the template to use
	if( editor /*&& [[editor principalClass] respondsToSelector:@selector(initWithResource:)]*/ )
	{
		// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
		id plug = [(id <ResKnifePluginProtocol>)[[editor principalClass] alloc] initWithResource:resource];
		if( plug ) return;
	}
	
	// if no editor exists, or the editor is broken, open using template
	[self openResource:resource usingTemplate:[resource type]];
}

- (void)openResource:(Resource *)resource usingTemplate:(NSString *)templateName
{
	// opens resource in template using TMPL resource with name templateName
	NSBundle *templateEditor = [NSBundle bundleWithPath:[[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent:@"Template Editor.plugin"]];
	
	// bug: this checks EVERY DOCUMENT for template resources (might not be desired)
	Resource *tmpl = [Resource resourceOfType:@"TMPL" withName:[resource type] inDocument:nil];
	
	// open the resources, passing in the template to use
	if( tmpl && [[templateEditor principalClass] respondsToSelector:@selector(initWithResources:)] )
	{
		// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
		// update: doug says window controllers automatically release themselves when their window is closed.
		NSWindowController *plugController = [(id <ResKnifePluginProtocol>)[[templateEditor principalClass] alloc] initWithResources:resource, tmpl, nil];
		if( plugController ) return;
	}
	
	// if no template exists, or template editor is broken, open as hex
	[self openResourceAsHex:resource];
}

- (void)openResourceAsHex:(Resource *)resource
{
	NSBundle *hexEditor = [NSBundle bundleWithPath:[[[NSBundle mainBundle] builtInPlugInsPath] stringByAppendingPathComponent:@"Hexadecimal Editor.plugin"]];
	// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
	
	NSWindowController *plugController = [(id <ResKnifePluginProtocol>)[[hexEditor principalClass] alloc] initWithResource:resource];
}

- (IBAction)playSound:(id)sender
{
	// bug: can only cope with one selected item
	NSData *data = [(Resource *)[outlineView itemAtRow:[outlineView selectedRow]] data];
	if( data && [data length] != 0 )
	{
		SndListPtr sndPtr = (SndListPtr) [data bytes];
		SndPlay( nil, &sndPtr, false );
	}
	else NSBeep();
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
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"ID Change for Ò%@Ó", nil), [resource name]]];
}

- (void)resourceTypeWillChange:(NSNotification *)notification
{
	// this saves the current resource's type so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setType:) object:[[[resource type] copy] autorelease]];
	if( [[resource name] length] == 0 )
		[[self undoManager] setActionName:NSLocalizedString(@"Type Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Type Change for Ò%@Ó", nil), [resource name]]];
}

- (void)resourceAttributesWillChange:(NSNotification *)notification
{
	// this saves the current state of the resource's attributes so we can undo the change
	Resource *resource = (Resource *) [notification object];
	[[self undoManager] registerUndoWithTarget:resource selector:@selector(setAttributes:) object:[[[resource attributes] copy] autorelease]];
	if( [[resource name] length] == 0 )
		[[self undoManager] setActionName:NSLocalizedString(@"Attributes Change", nil)];
	else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Attributes Change for Ò%@Ó", nil), [resource name]]];
}

/* EDIT OPERATIONS */
#pragma mark -

- (IBAction)clear:(id)sender
{
	if( [prefs boolForKey:@"DeleteResourceWarning"] )
	{
		NSBeginCriticalAlertSheet( @"Delete Resource", @"Delete", @"Cancel", nil, [self mainWindow], self, nil, @selector(deleteResourcesSheetDidDismiss:returnCode:contextInfo:), nil, @"Please confirm you wish to delete the selected resources." );
	}
	else [self deleteSelectedResources];
}

- (void)deleteResourcesSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
#pragma unused( contextInfo )
	if( returnCode == NSOKButton )
		[self deleteSelectedResources];
}

- (void)deleteSelectedResources
{
	Resource *resource;
	NSEnumerator *enumerator;
	NSArray *selectedItems = [outlineView selectedItems];
	
	// enumerate through array and delete resources
	[[self undoManager] beginUndoGrouping];
	enumerator = [selectedItems reverseObjectEnumerator];		// reverse so an undo will replace items in original order
	while( resource = [enumerator nextObject] )
	{
		[dataSource removeResource:resource];
		if( [[resource name] length] == 0 )
			[[self undoManager] setActionName:NSLocalizedString(@"Delete Resource", nil)];
		else [[self undoManager] setActionName:[NSString stringWithFormat:NSLocalizedString(@"Delete Resource Ò%@Ó", nil), [resource name]]];
	}
	[[self undoManager] endUndoGrouping];
	
	// generalise undo name if more than one was deleted
	if( [outlineView numberOfSelectedRows] > 1 )
		[[self undoManager] setActionName:NSLocalizedString(@"Delete Resources", nil)];
	
	// deselct resources (otherwise other resources move into selected rows!)
	[outlineView deselectAll:self];
}

/* FILE HANDLING */
#pragma mark -

/*- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	[savePanel setTreatsFilePackagesAsDirectories:YES];
	return YES;
}*/

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
	{
		NSLog( @"Opening Resource fork failed, trying data fork..." );
		error = FSOpenResourceFile( fileRef, 0, nil, fsRdPerm, &fileRefNum);
	}
	else fork = resourceForkName;
	SetResLoad( true );		// restore resource loading as soon as is possible
	
	// read the resources (without spawning thousands of undos for resource creation)
	[[self undoManager] disableUndoRegistration];
	if( fileRefNum && !error )
		succeeded = [self readResourceMap:fileRefNum];
	else if( !fileRefNum )
	{
		// supposed to read data fork as byte stream here
		NSLog( @"Opening data fork failed too! (fileRef)" );
	}
	else NSLog( @"Opening data fork failed too! (error)" );
	[[self undoManager] enableUndoRegistration];
	
	// tidy up loose ends
	if( !fork ) DisposePtr( (Ptr) resourceForkName );	// only delete if we're not saving it
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
				NSLog( @"Error reading resource map..." );
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
 	if( fork )
	{
		unichar *uniname = (unichar *) NewPtrClear( sizeof(unichar) *256 );
		[[fileName lastPathComponent] getCharacters:uniname];
		error = FSCreateResourceFile( parentRef, [[fileName lastPathComponent] length], (UniChar *) uniname, kFSCatInfoNone, nil, fork->length, (UniChar *) &fork->unicode, fileRef, fileSpec );
		if( !error )
			error = FSOpenResourceFile( fileRef, fork->length, (UniChar *) &fork->unicode, fsWrPerm, &fileRefNum);
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

- (NSWindow *)mainWindow
{
	return mainWindow;
}

- (ResourceDataSource *)dataSource
{
	return dataSource;
}

- (NSOutlineView *)outlineView
{
	return outlineView;
}

- (NSArray *)resources
{
	return resources;
}

- (NSString *)creator
{
	return creator;
}

- (NSString *)type
{
	return type;
}

- (IBAction)creatorChanged:(id)sender
{
	[self setCreator:[sender stringValue]];
}

- (IBAction)typeChanged:(id)sender
{
	[self setType:[sender stringValue]];
}

- (void)setCreator:(NSString *)newCreator
{
	if( ![newCreator isEqualToString:creator] )
	{
		id old = creator;
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoWillChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", newCreator, @"NSString creator", nil]];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setCreator:) object:creator];
		[[self undoManager] setActionName:NSLocalizedString( @"Change Creator Code", nil)];
		creator = [newCreator copy];
		[old release];
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoDidChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", newCreator, @"NSString creator", nil]];
	}
}

- (void)setType:(NSString *)newType
{
	if( ![newType isEqualToString:type] )
	{
		id old = type;
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoWillChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", newType, @"NSString type", nil]];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setType:) object:type];
		[[self undoManager] setActionName:NSLocalizedString( @"Change File Type", nil)];
		type = [newType copy];
		[old release];
		[[NSNotificationCenter defaultCenter] postNotificationName:DocumentInfoDidChangeNotification object:[NSDictionary dictionaryWithObjectsAndKeys:self, @"NSDocument", newType, @"NSString type", nil]];
	}
}

- (void)setCreator:(NSString *)newCreator andType:(NSString *)newType
{
	BOOL changeAction = ![newCreator isEqualToString:creator] && ![newType isEqualToString:type];
	[[self undoManager] beginUndoGrouping];
	[self setCreator:newCreator];
	[self setType:newType];
	[[self undoManager] endUndoGrouping];
	if( changeAction )
		[[self undoManager] setActionName:NSLocalizedString( @"Change Creator & Type", nil)];
}

@end
