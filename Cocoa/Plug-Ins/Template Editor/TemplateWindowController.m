#import "TemplateWindowController.h"
#import "ResourceStream.h"
#import "Element.h"
#import "ElementOCNT.h"
#import "ElementLSTB.h"
#import "ElementBBIT.h"
// and ones for keyed fields
#import "ElementDBYT.h"
#import "ElementDWRD.h"
#import "ElementDLNG.h"

#import "NSOutlineView-SelectedItems.h"
#import "CreateResourceSheetController.h"

@implementation TemplateWindowController
@synthesize dataList;
@synthesize resource;
@synthesize backup;

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource
{
	return [self initWithResource:newResource template:nil];
}

- (instancetype)initWithResource:(id <ResKnifeResource>)newResource template:(id <ResKnifeResource>)tmplResource
{
	self = [self initWithWindowNibName:@"TemplateWindow"];
	if (!self) {
		return nil;
	}
	
	//undoManager = [[NSUndoManager alloc] init];
	liveEdit = NO;
	if (liveEdit) {
		resource = newResource;	// resource to work on
		backup = [resource copy];	// for reverting only
	} else {
		backup = newResource;		// actual resource to change when saving data
		resource = [backup copy];	// resource to work on
	}
    resourceStructure = nil;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(templateDataDidChange:) name:ResourceDataDidChangeNotification object:tmplResource];
	[self readTemplate:tmplResource];	// reads (but doesn't retain) the template for this resource (TMPL resource with name equal to the passed resource's type)
	
	// load the window from the nib
	[self setShouldCascadeWindows:YES];
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
	[self loadResource];
	if(liveEdit)	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	else			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:backup];
	[[self window] setTitle:[resource defaultWindowTitle]];
	[self showWindow:self];
}

- (void)templateDataDidChange:(NSNotification *)notification
{
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

- (void)readTemplate:(id<ResKnifeResource>)tmplRes
{
    NSInputStream *stream = [[NSInputStream alloc] initWithData:[tmplRes data]];
    resourceStructure = [ElementList listFromStream:stream];
    resourceStructure.controller = self;
    [resourceStructure parseElements];
}

- (void)loadResource
{
    // create new stream
    ResourceStream *stream = [ResourceStream streamWithData:resource.data];
    // read the data into the template
    [resourceStructure readDataFrom:stream];
	
	// reload the view
	id item;
	[dataList reloadData];
	NSInteger row = [dataList numberOfRows];
	while ((item = [dataList itemAtRow:--row])) {
		[dataList expandItem:item expandChildren:YES];
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
    UInt32 size = 0;
    [resourceStructure sizeOnDisk:&size];
	
	// create data and stream
	NSMutableData *newData = [NSMutableData dataWithLength:size];
    ResourceStream *stream = [ResourceStream streamWithData:newData];
	
	// write bytes into new data object
    [resourceStructure writeDataTo:stream];
	
	// send the new resource data to ResKnife
	if (liveEdit) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:resource];
		[resource setData:newData];
		[backup setData:[newData copy]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
	} else {
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

#pragma mark -
#pragma mark Table Management

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    Element *element = (Element *)item;
    if ([tableColumn.identifier isEqualToString:@"data"]) {
        return [element dataView:outlineView];
    } else {
        NSTableCellView *view = [outlineView makeViewWithIdentifier:(tableColumn ? tableColumn.identifier : @"regularLabel") owner:self];
        view.textField.stringValue = element.label;
        return view;
    }
}

- (id)outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (item == nil)
		return [resourceStructure elementAtIndex:index];
	else
        return [item subElementAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return ([item subElementCount] > 0);
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (item == nil)
		return [resourceStructure count];
	else
        return [item subElementCount];
}

- (double)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    return [item rowHeight];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return [[(Element *)item type] isEqualToString:@"DVDR"];
}

#pragma mark -
#pragma mark Menu Management

- (IBAction)dataClicked:(id)sender
{
    // Edit the item clicked on
    // TODO: This doesn't work so nicely for additional fields in RECT/PNT
    if (dataList.clickedColumn == 1 && dataList.clickedRow != -1)
        [dataList editColumn:1 row:dataList.clickedRow withEvent:nil select:YES];
}

- (IBAction)itemValueUpdated:(id)sender
{
    if (liveEdit) {
        // remove self to avoid reloading the resource
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:resource];
        [[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:resource];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
    } else {
        [self setDocumentEdited:YES];
    }
}

// these next five methods are a crude hack - the items ought to be in the responder chain themselves
- (IBAction)createListEntry:(id)sender;
{
	// This works by selecting an item that serves as a template (another LSTB), or knows how to create an item (LSTE) and passing the message on to it.
	id element = [dataList selectedItem];
	if([element respondsToSelector:@selector(createListEntry)] && [element createListEntry])
	{
        NSInteger row = [dataList selectedRow];
		[dataList reloadData];
        [dataList selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
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

- (IBAction)delete:(id)sender;
{
    id element = [dataList selectedItem];
    if ([element respondsToSelector:@selector(removeListEntry)] && [element removeListEntry]) {
        [dataList reloadData];
        if(!liveEdit) [self setDocumentEdited:YES];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	Element *element = (Element*) [dataList selectedItem];
	if([item action] == @selector(createListEntry:))	return(element && [element respondsToSelector:@selector(createListEntry)]);
	else if([item action] == @selector(cut:))			return(element && [element respondsToSelector:@selector(cut:)]);
	else if([item action] == @selector(copy:))			return(element && [element respondsToSelector:@selector(copy:)]);
	else if([item action] == @selector(paste:) &&              element && [element respondsToSelector:@selector(validateMenuItem:)])
														return([element validateMenuItem:item]);
	else if([item action] == @selector(delete:))		return(element && [element respondsToSelector:@selector(removeListEntry)]);
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

@end
