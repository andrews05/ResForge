#import "TemplateWindowController.h"
#import "TemplateStream.h"
#import "Element.h"
#import "ElementOCNT.h"
#import "ElementLSTE.h"
// and ones for keyed fields
#import "ElementDBYT.h"
#import "ElementDWRD.h"
#import "ElementDLNG.h"

#import "NSOutlineView-SelectedItems.h"

@implementation TemplateWindowController

- (id)initWithResource:(id <ResKnifeResourceProtocol>)newResource
{
	return [self initWithResources:newResource, nil];
}

- (id)initWithResources:(id <ResKnifeResourceProtocol>)newResource, ...
{
	id tmplResource;
	va_list resourceList;
	
	va_start(resourceList, newResource);
	self = [self initWithWindowNibName:@"TemplateWindow"];
	if(!self)
	{
		va_end(resourceList);
		return nil;
	}
	
	toolbarItems = [[NSMutableDictionary alloc] init];
	//undoManager = [[NSUndoManager alloc] init];
	liveEdit = NO;
	if(liveEdit)
	{
		resource = newResource;	// resource to work on
		backup = [resource copy];	// for reverting only
	}
	else
	{
		backup = newResource;		// actual resource to change when saving data
		resource = [backup copy];	// resource to work on
	}
	templateStructure = [[NSMutableArray alloc] init];
	resourceStructure = [[NSMutableArray alloc] init];
	
	tmplResource = va_arg(resourceList, id);
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(templateDataDidChange:) name:ResourceDataDidChangeNotification object:tmplResource];
	[self readTemplate:tmplResource];	// reads (but doesn't retain) the template for this resource (TMPL resource with name equal to the passed resource's type)
	
	while((tmplResource = va_arg(resourceList, id)))
		NSLog(@"Too many params passed to -initWithResources:%@", [tmplResource description]);
	va_end(resourceList);
	
	// load the window from the nib
	[self setShouldCascadeWindows:YES];
	[self window];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
/*
- (void)windowControllerDidLoadNib:(NSWindowController *)controller
{
	[super windowControllerDidLoadNib:controller];
	[self setupToolbar:controller];
}
*/
- (void)windowDidLoad
{
	[super windowDidLoad];
	[self setupToolbar];
	[self loadResource];
	if(liveEdit)	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	else			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:backup];
	[[self window] setTitle:[resource defaultWindowTitle]];
	[[[dataList tableColumnWithIdentifier:@"label"] dataCell] setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
	[self showWindow:self];
	[displayList reloadData];
}

- (void)templateDataDidChange:(NSNotification *)notification
{
	[templateStructure removeAllObjects];
	[self readTemplate:[notification object]];
	if([self isWindowLoaded])
		[self loadResource];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	if(!liveEdit)
		// bug: should display alert asking if you want to replace data in this editor or reassert this data, revoking the other editor's changes
		[resource setData:[[backup data] copy]];
	[self loadResource];
}

- (void)loadResource
{
	// create new stream
	TemplateStream *stream = [TemplateStream streamWithBytes:(char *)[[resource data] bytes] length:[[resource data] length]];
	
	// loop through template cloning its elements
	Element *element;
	[resourceStructure removeAllObjects];
	NSEnumerator *enumerator = [templateStructure objectEnumerator];
	while(element = [enumerator nextObject])
	{
		Element *clone = [element copy];	// copy the template object.
		//NSLog(@"clone = %@; resourceStructure = %@", clone, resourceStructure);
		[resourceStructure addObject:clone];			// add it to our parsed resource data list. Do this right away so the element can append other items should it desire to.
		[clone setParentArray:resourceStructure];		// the parent for these is the root level resourceStructure object
		Class cc = [clone class];
		
		BOOL pushedCounter = NO;
		//BOOL pushedKey = NO;
		if(cc == [ElementOCNT class])
		{	[stream pushCounter:(ElementOCNT *)clone]; pushedCounter = YES; }
		if(cc == [ElementKBYT class] ||
		   cc == [ElementKWRD class] ||
		   cc == [ElementKLNG class] )
		{	[stream pushKey:clone]; /* pushedKey = YES; */ }
		[clone readDataFrom:stream];				// fill it with resource data.
		if(cc == [ElementLSTE class] && pushedCounter)
			[stream popCounter];
//		if(cc == [ElementKEYE class] && pushedKey)
//			[stream popKey];
	}
	
	// reload the view
	id item;
	[dataList reloadData];
	int row = [dataList numberOfRows];
	while((item = [dataList itemAtRow: --row]))
	{
		if([dataList isExpandable: item] && ![dataList isItemExpanded: item])
			[dataList expandItem: item expandChildren: YES];
	}
}

- (BOOL)windowShouldClose:(id)sender
{
	[[self window] makeFirstResponder:dataList];
	[dataList abortEditing];
	
	if([[self window] isDocumentEdited])
	{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSBeginAlertSheet(NSLocalizedStringFromTableInBundle(@"KeepChangesDialogTitle", nil, bundle, nil), NSLocalizedStringFromTableInBundle(@"KeepChangesButton", nil, bundle, nil), NSLocalizedStringFromTableInBundle(@"DiscardChangesButton", nil, bundle, nil), NSLocalizedStringFromTableInBundle(@"CancelButton", nil, bundle, nil), sender, self, @selector(saveSheetDidClose:returnCode:contextInfo:), nil, nil, NSLocalizedStringFromTableInBundle(@"KeepChangesDialogMessage", nil, bundle, nil));
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
	// get size of resource by summing size of all fields
	Element *element;
	unsigned int size = 0;
	NSEnumerator *enumerator = [resourceStructure objectEnumerator];
	while(element = [enumerator nextObject])
		size += [element sizeOnDisk];
	
	// create data and stream
	NSMutableData *newData = [NSMutableData dataWithLength:size];
	TemplateStream *stream = [TemplateStream streamWithBytes:(char *)[newData bytes] length:size];
	
	// write bytes into new data object
	enumerator = [resourceStructure objectEnumerator];
	while(element = [enumerator nextObject])
		[element writeDataTo:stream];
	
	// send the new resource data to ResKnife
	if(liveEdit)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:resource];
		[resource setData:newData];
		[backup setData:[newData copy]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	}
	else
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:backup];
		[resource setData:newData];
		[backup setData:[newData copy]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:backup];
		[self setDocumentEdited:NO];
	}
}

- (void)revertResource:(id)sender
{
	[resource setData:[[backup data] copy]];
}

- (void)readTemplate:(id<ResKnifeResourceProtocol>)tmplRes
{
	char *data = (char*) [[tmplRes data] bytes];
	unsigned long bytesToGo = [[tmplRes data] length];
	TemplateStream *stream = [TemplateStream streamWithBytes:data length:bytesToGo];
	
	// read new fields from the template and add them to our list
	while([stream bytesToGo] > 0)
	{
		Element *element = [stream readOneElement];
		if(element)
		{
			[element setIsTMPL:YES];	// for debugging
			[templateStructure addObject:element];
		}
		else
		{
			NSLog(@"Error reading template stream, aborting.");
			break;
		}
	}
	
	[displayList reloadData];
}

#pragma mark -
#pragma mark Table Management

- (id)outlineView:(NSOutlineView*)outlineView child:(int)index ofItem:(id)item
{
	if((item == nil) && (outlineView == displayList))
		return [templateStructure objectAtIndex:index];
	else if((item == nil) && (outlineView == dataList))
		return [resourceStructure objectAtIndex:index];
	else return [item subElementAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return ([item subElementCount] > 0);
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if((item == nil) && (outlineView == displayList))
		return [templateStructure count];
	else if((item == nil) && (outlineView == dataList))
		return [resourceStructure count];
	else return [item subElementCount];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [item valueForKey:[tableColumn identifier]];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	id old = [item valueForKey:[tableColumn identifier]];
	if([(Element *)item editable] && ![old isEqual:object])
	{
//		[[self undoManager] registerUndoWithTarget:item selector:@selector(setStringValue:) object:old];
//		[[self undoManager] setActionName:NSLocalizedString(@"Changes", nil)];
		[item setValue:object forKey:[tableColumn identifier]];
		if(!liveEdit) [self setDocumentEdited:YES];
		
		// remove self to avoid reloading the resource
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:resource];
		[[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:resource];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return [(Element *)item editable];
}

/*- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return [item rowHeight];
}*/

#pragma mark -
#pragma mark Menu Management

// these next five methods are a crude hack - the items ought to be in the responder chain themselves
- (IBAction)createListEntry:(id)sender;
{
	// This works by selecting an item that serves as a template (another LSTB), or knows how to create an item (LSTE) and passing the message on to it.
	id element = [dataList selectedItem];
	if([element respondsToSelector:@selector(createListEntry:)])
	{
		[element createListEntry:sender];
		[dataList reloadData];
		[dataList expandItem:[dataList selectedItem] expandChildren:YES];
		if(!liveEdit) [self setDocumentEdited:YES];
	}
}

- (IBAction)cut:(id)sender;
{
	[[dataList selectedItem] cut:sender];
	[dataList reloadData];
	if(!liveEdit) [self setDocumentEdited:YES];
}

- (IBAction)copy:(id)sender;
{
	[[dataList selectedItem] copy:sender];
	[dataList reloadData];
}

- (IBAction)paste:(id)sender;
{
	[[dataList selectedItem] paste:sender];
	[dataList reloadData];
	if(!liveEdit) [self setDocumentEdited:YES];
}

- (IBAction)clear:(id)sender;
{
	[[dataList selectedItem] clear:sender];
	[dataList reloadData];
	if(!liveEdit) [self setDocumentEdited:YES];
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	Element *element = (Element*) [dataList selectedItem];
	if([item action] == @selector(createListEntry:))	return(element && [element respondsToSelector:@selector(createListEntry:)]);
	else if([item action] == @selector(cut:))			return(element && [element respondsToSelector:@selector(cut:)]);
	else if([item action] == @selector(copy:))			return(element && [element respondsToSelector:@selector(copy:)]);
	else if([item action] == @selector(paste:) &&              element && [element respondsToSelector:@selector(validateMenuItem:)])
														return([element validateMenuItem:item]);
	else if([item action] == @selector(clear:))			return(element && [element respondsToSelector:@selector(clear:)]);
	else if([item action] == @selector(saveDocument:))	return YES;
	else return NO;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemAtIndex:[resourceMenu indexOfItemWithTarget:nil andAction:@selector(showCreateResourceSheet:)]];
	[createItem setTitle:NSLocalizedString(@"Create List Entry", nil)];
	[createItem setAction:@selector(createListEntry:)];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [resource defaultWindowTitle];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemAtIndex:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemAtIndex:[resourceMenu indexOfItemWithTarget:nil andAction:@selector(createListEntry:)]];
	[createItem setTitle:NSLocalizedString(@"Create New Resource...", nil)];
	[createItem setAction:@selector(showCreateResourceSheet:)];
}

#pragma mark -
#pragma mark Toolbar Management

static NSString *RKTEToolbarIdentifier		= @"com.nickshanks.resknife.templateeditor.toolbar";
static NSString *RKTEDisplayTMPLIdentifier	= @"com.nickshanks.resknife.templateeditor.toolbar.tmpl";

- (void)setupToolbar
{
	/* This routine should become invalid once toolbars are integrated into nib files */
	
	NSToolbarItem *item;
	[toolbarItems removeAllObjects];	// just in case this method is called more than once per document (which it shouldn't be!)
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:RKTEDisplayTMPLIdentifier];
	[item setLabel:NSLocalizedString(@"Parsed TMPL", nil)];
	[item setPaletteLabel:NSLocalizedString(@"Display Parsed TMPL", nil)];
	[item setToolTip:NSLocalizedString(@"Display Parsed TMPL", nil)];
	[item setImage:[NSImage imageNamed:@"DisplayTMPL"]];
	[item setTarget:tmplDrawer];
	[item setAction:@selector(toggle:)];
	[toolbarItems setObject:item forKey:RKTEDisplayTMPLIdentifier];
	
	NSToolbar *toolbar = [[NSToolbar alloc] initWithIdentifier:RKTEToolbarIdentifier];
	
	// set toolbar properties
	[toolbar setVisible:NO];
	[toolbar setAutosavesConfiguration:YES];
	[toolbar setAllowsUserCustomization:YES];
	[toolbar setDisplayMode:NSToolbarDisplayModeLabelOnly];
	[toolbar setSizeMode:NSToolbarSizeModeSmall];
	
	// attach toolbar to window
	[toolbar setDelegate:self];
	[[self window] setToolbar:toolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [toolbarItems objectForKey:itemIdentifier];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKTEDisplayTMPLIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarPrintItemIdentifier, nil];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:RKTEDisplayTMPLIdentifier, NSToolbarPrintItemIdentifier, NSToolbarCustomizeToolbarItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier, nil];
}

@end

#pragma mark -
#pragma mark Table Event Handling

@implementation NTOutlineView
- (void)keyDown:(NSEvent *)event
{
	Element *selectedItem = nil;
	int selectedRow = [self selectedRow];
	if(selectedRow != -1)
		selectedItem = [self selectedItem];
	
	if(selectedItem && [selectedItem editable] && ([[event characters] isEqualToString:@"\r"] || [[event characters] isEqualToString:@"\t"]))
		[self editColumn:1 row:selectedRow withEvent:nil select:YES];
	else if(selectedItem && [selectedItem respondsToSelector:@selector(clear:)] && [[event characters] isEqualToString:@"\x7F"])
		[[[self window] windowController] clear:nil];
	else [super keyDown:event];
}
- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector
{
	// pressed return, end editing
	if(selector == @selector(insertNewline:))
	{
		[[self window] makeFirstResponder:self];
		[self abortEditing];
		return YES;
	}
	return [super textView:textView doCommandBySelector:selector];
}
@end