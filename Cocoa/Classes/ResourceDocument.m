/* =============================================================================
	PROJECT:	ResKnife
	FILE:		ResourceDocument.m
	
	PURPOSE:
		This is a ResKnife document (I still write Resurrection occasionally,
		sorry Nick...), it handles loading, display etc. of resources.
		
		It uses a separate object as the data source for its outline view,
		though, ResourceDataSource. I'd better ask Nick why.
	
	AUTHORS:	Nick Shanks, nick(at)nickshanks.com, (c) ~2001.
				M. Uli Kusterer, witness(at)zathras.de, (c) 2003.
	
	REVISIONS:
		2003-07-31  UK  Added support for plugin registry, commented.
   ========================================================================== */

/* -----------------------------------------------------------------------------
	Headers:
   -------------------------------------------------------------------------- */

#import "ResourceDocument.h"
#import "ResourceDataSource.h"
#import "ResourceNameCell.h"
#import "Resource.h"
#import "PrefsWindowController.h"
#import "CreateResourceSheetController.h"
#import "OutlineViewDelegate.h"
#import "NSOutlineView-SelectedItems.h"

#import "ResKnifePluginProtocol.h"
#import "RKEditorRegistry.h"


/* -----------------------------------------------------------------------------
	Notification names:
   -------------------------------------------------------------------------- */

NSString *DocumentInfoWillChangeNotification		= @"DocumentInfoWillChangeNotification";
NSString *DocumentInfoDidChangeNotification			= @"DocumentInfoDidChangeNotification";


extern NSString *RKResourcePboardType;

@implementation ResourceDocument

- (id)init
{
	self = [super init];
	if( !self )
		return nil;
	toolbarItems = [[NSMutableDictionary alloc] init];
	resources = [[NSMutableArray alloc] init];
	fork = nil;
	creator = [@"ResK" retain];
	type = [@"rsrc" retain];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if( fork ) DisposePtr( (Ptr) fork );
	[resources release];
	[toolbarItems release];
	[type release];
	[creator release];
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
	[outlineView swapForOutlineSortView];
	[outlineView setTarget:self];
	[outlineView setDoubleAction:@selector(openResources:)];
	
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
	else if( [item action] == @selector(exportResourceToImageFile:) )
	{
		Class   edClass;
		
		if( selectedRows < 1 )
			return NO;
		
		edClass = [[RKEditorRegistry mainRegistry] editorForType: [resource type]];
		return [edClass respondsToSelector:@selector(imageForImageFileExport:)];
	}
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
static NSString *RKExportItemIdentifier		= @"com.ulikusterer.resknife.toolbar.export";

- (void)setupToolbar:(NSWindowController *)windowController
{
	/* This routine should become invalid once toolbars are integrated into nib files */
	
	NSToolbarItem *item;
	[toolbarItems removeAllObjects];	// just in case this method is called more than once per document (which it shouldn't be!)
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKCreateItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Create", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Create", nil)];
	[item setToolTip:NSLocalizedString(@"Create New Resource", nil)];
	[item setImage:[NSImage imageNamed:@"Create"]];
	[item setTarget:self];
	[item setAction:@selector(showCreateResourceSheet:)];
	[toolbarItems setObject:item forKey:RKCreateItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKDeleteItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Delete", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Delete", nil)];
	[item setToolTip:NSLocalizedString(@"Delete Selected Resource", nil)];
	[item setImage:[NSImage imageNamed:@"Delete"]];
	[item setTarget:self];
	[item setAction:@selector(clear:)];
	[toolbarItems setObject:item forKey:RKDeleteItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKEditItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Edit", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Edit", nil)];
	[item setToolTip:NSLocalizedString(@"Edit Resource In Default Editor", nil)];
	[item setImage:[NSImage imageNamed:@"Edit"]];
	[item setTarget:self];
	[item setAction:@selector(openResources:)];
	[toolbarItems setObject:item forKey:RKEditItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKEditHexItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Edit Hex", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Edit Hex", nil)];
	[item setToolTip:NSLocalizedString(@"Edit Resource As Hexadecimal", nil)];
	[item setImage:[NSImage imageNamed:@"Edit Hex"]];
	[item setTarget:self];
	[item setAction:@selector(openResourcesAsHex:)];
	[toolbarItems setObject:item forKey:RKEditHexItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKSaveItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Save", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Save", nil)];
	[item setToolTip:[NSString stringWithFormat:NSLocalizedString(@"Save To %@ Fork", nil), !fork? NSLocalizedString(@"Data", nil) : NSLocalizedString(@"Resource", nil)]];
	[item setImage:[NSImage imageNamed:@"Save"]];
	[item setTarget:self];
	[item setAction:@selector(saveDocument:)];
	[toolbarItems setObject:item forKey:RKSaveItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKShowInfoItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Show Info", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Show Info", nil)];
	[item setToolTip:NSLocalizedString(@"Show Resource Information Window", nil)];
	[item setImage:[NSImage imageNamed:@"Show Info"]];
	[item setTarget:[NSApp delegate]];
	[item setAction:@selector(showInfo:)];
	[toolbarItems setObject:item forKey:RKShowInfoItemIdentifier];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKExportItemIdentifier];
	[item autorelease];
	[item setLabel:NSLocalizedString(@"Export Data", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Export Resource Data", nil)];
	[item setToolTip:NSLocalizedString(@"Export the resource's data to a file", nil)];
	[item setImage:[NSImage imageNamed:@"Export"]];
	[item setTarget:self];
	[item setAction:@selector(exportResourceToFile:)];
	[toolbarItems setObject:item forKey:RKExportItemIdentifier];
	
	if( [windowController window] == mainWindow )
	{
		NSToolbar *toolbar = [[[NSToolbar alloc] initWithIdentifier:RKToolbarIdentifier] autorelease];
		
		// set toolbar properties
		[toolbar setVisible:YES];
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
    return [NSArray arrayWithObjects:RKCreateItemIdentifier, RKShowInfoItemIdentifier, RKDeleteItemIdentifier, NSToolbarSeparatorItemIdentifier, RKEditItemIdentifier, RKEditHexItemIdentifier, NSToolbarSeparatorItemIdentifier, RKSaveItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKCreateItemIdentifier, RKDeleteItemIdentifier, RKEditItemIdentifier, RKEditHexItemIdentifier, RKSaveItemIdentifier, RKExportItemIdentifier, RKShowInfoItemIdentifier, NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
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
	else if( [identifier isEqualToString:RKExportItemIdentifier] )			valid = selectedRows > 0;
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


/* -----------------------------------------------------------------------------
	openResourceUsingEditor:
		Open an editor for the specified Resource instance. This looks up
		the editor to use in the plugin registry and then instantiates an
		editor object, handing it the resource. If there is no editor for this
		type registered, it falls back to the template editor, which in turn
		uses the hex editor as a fallback.
	
	REVISIONS:
		2003-07-31  UK  Changed to use plugin registry instead of file name.
   -------------------------------------------------------------------------- */

-(void) openResourceUsingEditor: (Resource*)resource
{
	Class					editorClass = [[RKEditorRegistry mainRegistry] editorForType: [resource type]];
	
	// open the resources, passing in the template to use
	if( editorClass )
	{
		// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
		// update: doug says window controllers automatically release themselves when their window is closed.
		id plug = [(id <ResKnifePluginProtocol>)[editorClass alloc] initWithResource:resource];
		if( plug ) return;
	}
	
	// if no editor exists, or the editor is broken, open using template
	[self openResource:resource usingTemplate:[resource type]];
}


/* -----------------------------------------------------------------------------
	openResource:usingTemplate:
		Open a template editor for the specified Resource instance. This looks
		up the template editor in the plugin registry and then instantiates an
		editor object, handing it the resource and the template resource to use.
		If there is no template editor registered, or there is no template for
		this resource type, it falls back to the hex editor.
	
	REVISIONS:
		2003-07-31  UK  Changed to use plugin registry instead of file name.
   -------------------------------------------------------------------------- */

-(void) openResource: (Resource*)resource usingTemplate: (NSString*)templateName
{
	// opens resource in template using TMPL resource with name templateName
	Class					editorClass = [[RKEditorRegistry mainRegistry] editorForType: @"Template Editor"];
	
	// TODO: this checks EVERY DOCUMENT for template resources (might not be desired)
	// TODO: it doesn't, however, check the application's resource map for a matching template!
	Resource *tmpl = [Resource resourceOfType:@"TMPL" withName:[resource type] inDocument:nil];
	
	// open the resources, passing in the template to use
	if( tmpl && editorClass )
	{
		// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
		// update: doug says window controllers automatically release themselves when their window is closed.
		NSWindowController *plugController = [(id <ResKnifeTemplatePluginProtocol>)[editorClass alloc] initWithResources:resource, tmpl, nil];
		if( plugController ) return;
	}
	
	// if no template exists, or template editor is broken, open as hex
	[self openResourceAsHex:resource];
}


/* -----------------------------------------------------------------------------
	openResourceAsHex:
		Open a hex editor for the specified Resource instance. This looks
		up the hexadecimal editor in the plugin registry and then instantiates an
		editor object, handing it the resource.
	
	REVISIONS:
		2003-07-31  UK  Changed to use plugin registry instead of file name.
   -------------------------------------------------------------------------- */

-(void) openResourceAsHex: (Resource*)resource
{
	Class					editorClass = [[RKEditorRegistry mainRegistry] editorForType: @"Hexadecimal Editor"];
	// bug: I alloc a plug instance here, but have no idea where I should dealloc it, perhaps the plug ought to call [self autorelease] when it's last window is closed?
	// update: doug says window controllers automatically release themselves when their window is closed.
	NSWindowController *plugController = [(id <ResKnifePluginProtocol>)[editorClass alloc] initWithResource:resource];
}


// TODO:	These two should really be moved to a 'snd ' editor, but first we'd
//			need to extend the plugin protocol to call the class so it can add
//			such menu items. Of course, we could just make the 'snd ' editor
//			have a button in its window that plays the sound.
- (IBAction)playSound:(id)sender
{
	// bug: can only cope with one selected item
	NSData *data = [(Resource *)[outlineView itemAtRow:[outlineView selectedRow]] data];
	if( data && [data length] != 0 )
	{
		// bug: plays sound synchronously in main thread!
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

- (IBAction)cut:(id)sender
{
	[self copy:sender];
	[self clear:sender];
}

- (IBAction)copy:(id)sender
{
	#pragma unused( sender )
	NSArray *selectedItems = [outlineView selectedItems];
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	[pb declareTypes:[NSArray arrayWithObject:RKResourcePboardType] owner:self];
	[pb setData:[NSArchiver archivedDataWithRootObject:selectedItems] forType:RKResourcePboardType];
}

- (IBAction)paste:(id)sender
{
	#pragma unused( sender )
	NSPasteboard *pb = [NSPasteboard pasteboardWithName:NSGeneralPboard];
	if( [pb availableTypeFromArray:[NSArray arrayWithObject:RKResourcePboardType]] )
		[self pasteResources:[NSUnarchiver unarchiveObjectWithData:[pb dataForType:RKResourcePboardType]]];
}

- (void)pasteResources:(NSArray *)pastedResources
{
	Resource *resource;
	NSEnumerator *enumerator = [pastedResources objectEnumerator];
	while( resource = (Resource *) [enumerator nextObject] )
	{
		// check resource type/ID is available
		if( [dataSource resourceOfType:[resource type] andID:[resource resID]] == nil )
		{
			// resource slot is available, paste this one in
			[dataSource addResource:resource];
		}
		else
		{
			// resource slot is ocupied, ask user what to do
			NSMutableArray *remainingResources = [[NSMutableArray alloc] initWithCapacity:1];
			[remainingResources addObject:resource];
			[remainingResources addObjectsFromArray:[enumerator allObjects]];
			NSBeginAlertSheet( @"Paste Error", @"Unique ID", @"Skip", @"Overwrite", mainWindow, self, NULL, @selector(overwritePasteSheetDidDismiss:returnCode:contextInfo:), remainingResources, @"There already exists a resource of type %@ with ID %@. Do you wish to assign the pasted resource a unique ID, overwrite the existing resource, or skip pasting of this resource?", [resource type], [resource resID] );
		}
	}
}

- (void)overwritePasteSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSMutableArray *remainingResources = [NSMutableArray arrayWithArray:[(NSArray *)contextInfo autorelease]];
	Resource *resource = [remainingResources objectAtIndex:0];
	if( returnCode == NSAlertDefaultReturn )	// unique ID
	{
		Resource *newResource = [Resource resourceOfType:[resource type] andID:[dataSource uniqueIDForType:[resource type]] withName:[resource name] andAttributes:[resource attributes] data:[resource data]];
		[dataSource addResource:newResource];
	}
	else if( NSAlertOtherReturn )				// overwrite
	{
		[dataSource removeResource:[dataSource resourceOfType:[resource type] andID:[resource resID]]];
		[dataSource addResource:resource];
	}
//	else if( NSAlertAlternateReturn )			// skip
	
	// remove top resource and continue paste
	[remainingResources removeObjectAtIndex:0];
	[self pasteResources:remainingResources];
}

- (IBAction)clear:(id)sender
{
	#pragma unused( sender )
	if( [prefs boolForKey:@"DeleteResourceWarning"] )
	{
		NSBeginCriticalAlertSheet( @"Delete Resource", @"Delete", @"Cancel", nil, [self mainWindow], self, @selector(deleteResourcesSheetDidEnd:returnCode:contextInfo:), NULL, nil, @"Please confirm you wish to delete the selected resources." );
	}
	else [self deleteSelectedResources];
}

- (void)deleteResourcesSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
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
	
	// deselect resources (otherwise other resources move into selected rows!)
	[outlineView deselectAll:self];
}

/* FILE HANDLING */
#pragma mark -

/*- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	[savePanel setTreatsFilePackagesAsDirectories:YES];
	return YES;
}*/


/* -----------------------------------------------------------------------------
	readFromFile:ofType:
		Open the specified file and read its resources. This first tries to
		load the resources from the res fork, and failing that tries the data
		fork.
	
	REVISIONS:
		2003-08-01  UK  Commented.
   -------------------------------------------------------------------------- */

-(BOOL) readFromFile: (NSString*)fileName ofType: (NSString*)fileKind
{
	BOOL			succeeded = NO;
	OSStatus		error = noErr;
	HFSUniStr255	*resourceForkName = (HFSUniStr255 *) NewPtrClear( sizeof(HFSUniStr255) );   // This may be saved away in the instance variable "fork" to keep track of which fork our resources are in.
	FSRef			*fileRef = (FSRef *) NewPtrClear( sizeof(FSRef) );
	SInt16			fileRefNum = 0;
	FSCatalogInfo   info = { 0 };
	
	// open fork with resources in it
	error = FSPathMakeRef( [fileName cString], fileRef, nil );
	error = FSGetResourceForkName( resourceForkName );
	SetResLoad( false );	// don't load "preload" resources
	
	[type release];
	[creator release];
	
	error = FSGetCatalogInfo( fileRef, kFSCatInfoFinderInfo, &info, nil, nil, nil );
	type = [[NSString stringWithCString: &((FileInfo*)info.finderInfo)->fileType length:4] retain];
	creator = [[NSString stringWithCString: &((FileInfo*)info.finderInfo)->fileCreator length:4] retain];
	
	// Try res fork first:
	error = FSOpenResourceFile( fileRef, resourceForkName->length, (UniChar *) &resourceForkName->unicode, fsRdPerm, &fileRefNum);
	if( error )				// try to open data fork instead
	{
		NSLog( @"Opening Resource fork failed, trying data fork..." );
		error = FSOpenResourceFile( fileRef, 0, nil, fsRdPerm, &fileRefNum);
	}
	else
	{
		fork = resourceForkName;
		[self readFork:@"" asStreamFromFile:fileName];		// bug: only reads data fork for now, need to scan file for other forks too
	}
	SetResLoad( true );		// restore resource loading as soon as is possible
	
	// read the resources (without spawning thousands of undos for resource creation)
	[[self undoManager] disableUndoRegistration];
	if( fileRefNum && error == noErr )
		succeeded = [self readResourceMap:fileRefNum];
	else if( !fileRefNum )
	{
		// supposed to read data fork as byte stream here
		NSLog( @"Opening data fork failed too! (fileRef)" );
	}
	else NSLog( @"Opening data fork failed too! (error)" );
	[[self undoManager] enableUndoRegistration];
	
	// tidy up loose ends
	if( !fork ) DisposePtr( (Ptr) resourceForkName );	// only delete if we're not saving it to "fork" instance var.
	if( fileRefNum ) FSClose( fileRefNum );
	DisposePtr( (Ptr) fileRef );
	return succeeded;
}

- (BOOL)readFork:(NSString *)forkName asStreamFromFile:(NSString *)fileName
{
	NSData		*data		= [NSData dataWithContentsOfFile:fileName];
	Resource	*resource	= [Resource resourceOfType:@"" andID:0 withName:NSLocalizedString(@"Data Fork", nil) andAttributes:0 data:data];
	if( data && resource )
	{
		/* NTFS Note: When running SFM (Services for Macintosh) a Windows NT-based system (including 2000 & XP) serving NTFS-formatted drives stores Mac resource forks in a stream named "AFP_Resource". The finder info/attributes are stored in a stream called "Afp_AfpInfo". The default data fork stream is called "$DATA" and any of these can be accessed thus: "c:\filename.txt:forkname". 
		As a result, ResKnife prohibits creation of forks with the following names:	"" (empty string, Mac data fork name),
																					"$DATA" (NTFS data fork name),
																					"AFP_Resource" and "Afp_AfpInfo".
		It is perfectly legal in ResKnife to read in forks of these names when accessing a shared NTFS drive from a server running SFM. */
		
		[resource setRepresentedFork:forkName];
		[resource setDocument:self];
		[resources insertObject:resource atIndex:0];
		return YES;
	}
	else return NO;
}

-(BOOL) readResourceMap: (SInt16)fileRefNum
{
	OSStatus error = noErr;
	unsigned short n;
	unsigned short i;
	SInt16 oldResFile = CurResFile();
	UseResFile( fileRefNum );
	
	for( i = 1; i <= Count1Types(); i++ )
	{
		ResType resType;
		unsigned short j;
	
		Get1IndType( &resType, i );
		n = Count1Resources( resType );
		for( j = 1; j <= n; j++ )
		{
			Str255		nameStr;
			long		sizeLong;
			short		resIDShort;
			short		attrsShort;
			Handle		resourceHandle;
			NSString	*name;
			NSString	*type;
			NSNumber	*resID;
			NSNumber	*attributes;
			NSData		*data;
			Resource	*resource;
			
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
			name		= [NSString stringWithCString:&nameStr[1] length:nameStr[0]];
			type		= [NSString stringWithCString:(char *) &resType length:4];
			resID		= [NSNumber numberWithShort:resIDShort];
			attributes	= [NSNumber numberWithShort:attrsShort];
			data		= [NSData dataWithBytes:*resourceHandle length:sizeLong];
			resource	= [Resource resourceOfType:type andID:resID withName:name andAttributes:attributes data:data];
			[resource setDocument:self];
			[resources addObject:resource];		// array retains resource
			
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
			
			/* at some point make use of:
			
			FSCreateResourceFork(	const FSRef *    ref,
									UniCharCount     forkNameLength,
									const UniChar *  forkName,             // can be NULL
									UInt32           flags);
			
			Creates the named fork and initalises as a resource fork
			
			Mac OS 10.2 or later */
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


/* -----------------------------------------------------------------------------
	writeResourceMap:
		Writes all resources (except the ones representing other forks of the
		file) to the specified resource file.
	
	REVISIONS:
		2003-08-01  UK  Swiss national holiday, and I'm stuck in Germany...
						Commented, changed to use enumerator instead of
						objectAtIndex.
   -------------------------------------------------------------------------- */

-(BOOL) writeResourceMap: (SInt16)fileRefNum
{
	OSStatus		error = noErr;
	NSEnumerator*   enny;
	Resource		*resource;
	
	// Make the resource file current:
	SInt16			oldResFile = CurResFile();
	UseResFile( fileRefNum );
	
	// Loop over all our resources:
	for( enny = [resources objectEnumerator]; resource = [enny nextObject]; )
	{
		Str255	nameStr;
		ResType	resType;
		short	resIDShort;
		short	attrsShort;
		Handle	resourceHandle;

		// Resource represents another fork in the file? Skip it.
		if( [resource representedFork] != nil ) continue;
		
		resIDShort	= [[resource resID] shortValue];
		attrsShort	= [[resource attributes] shortValue];
		resourceHandle = NewHandleClear( [[resource data] length] );
		
		// Unicode name -> P-String:
		nameStr[0] = [[resource name] cStringLength];
		BlockMoveData( [[resource name] cString], &nameStr[1], nameStr[0] );
		
		// Type string to ResType:
		[[resource type] getCString:(char *) &resType maxLength:4];
		
		// NSData to resource data Handle:
		HLockHi( resourceHandle );
		[[resource data] getBytes:*resourceHandle];
		HUnlock( resourceHandle );
		
		// Now that everything's converted, write it to our file:
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
	
	// Save resource map and clean up:
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


-(void)		exportDataPanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSData* data = contextInfo;
	[data autorelease];
	
	if( returnCode == NSOKButton )
		[data writeToFile:[sheet filename] atomically: YES];
}


-(void)		exportImagePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSImage* img = contextInfo;
	[img autorelease];
	
	if( returnCode == NSOKButton )
	{
		NSData* data = [img TIFFRepresentation];
		[data writeToFile:[sheet filename] atomically: YES];
	}
}


-(IBAction)		exportResourceToFile: (id)sender
{
	Resource*		resource = (Resource*) [outlineView selectedItem];
	NSData*			theData;
	Class			edClass = [[RKEditorRegistry mainRegistry] editorForType: [resource type]];
	NSString*		extension = [resource type];
	NSSavePanel*	panel;
	NSString*		fName;

	if( [edClass respondsToSelector:@selector(dataForFileExport:)] )
		theData = [edClass dataForFileExport: resource];
	else
		theData = [resource data];
	
	if( [edClass respondsToSelector:@selector(extensionForFileExport:)] )
		extension = [edClass extensionForFileExport];

	panel = [NSSavePanel savePanel];
	fName = [[resource name] stringByAppendingFormat: @".%@", extension];

	[panel beginSheetForDirectory:nil file:fName modalForWindow:mainWindow modalDelegate:self
			didEndSelector:@selector(exportDataPanelDidEnd:returnCode:contextInfo:) contextInfo:[theData retain]];
}


-(IBAction)		exportResourceToImageFile: (id)sender
{
	Resource*		resource = (Resource*) [outlineView selectedItem];
	NSImage*		theData;
	Class			edClass = [[RKEditorRegistry mainRegistry] editorForType: [resource type]];
	NSString*		extension = @"tiff";
	NSSavePanel*	panel;
	NSString*		fName;
	
	if( ![edClass respondsToSelector:@selector(imageForImageFileExport:)] )
		return;
	
	theData = [edClass imageForImageFileExport: resource];

	if( [edClass respondsToSelector:@selector(extensionForImageFileExport:)] )
		extension = [edClass extensionForFileExport];
	
	panel = [NSSavePanel savePanel];
	fName = [[resource name] stringByAppendingFormat: @".%@", extension];
	
	[panel beginSheetForDirectory:nil file:fName modalForWindow:mainWindow modalDelegate:self
			didEndSelector:@selector(exportImagePanelDidEnd:returnCode:contextInfo:) contextInfo:[theData retain]];
}

@end
