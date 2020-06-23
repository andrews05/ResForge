#import "TemplateWindowController.h"
#import "ResourceStream.h"
#import "Element.h"
#import "ElementLSTB.h"

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
    [self loadResource];
	
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
    [dataList expandItem:nil expandChildren:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(resourceDataDidChange:)
                                                 name:ResourceDataDidChangeNotification
                                               object:(liveEdit ? resource : backup)];
	[self.window setTitle:resource.defaultWindowTitle];
	[self showWindow:self];
}

- (void)templateDataDidChange:(NSNotification *)notification
{
	[self readTemplate:[notification object]];
	if ([self isWindowLoaded])
		[self loadResource];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
	if (!liveEdit)
		// bug: should display alert asking if you want to replace data in this editor or reassert this data, revoking the other editor's changes
		[resource setData:[backup.data copy]];
	[self loadResource];
}

- (void)readTemplate:(id<ResKnifeResource>)tmplRes
{
    NSInputStream *stream = [[NSInputStream alloc] initWithData:tmplRes.data];
    resourceStructure = [ElementList listFromStream:stream];
    resourceStructure.controller = self;
    [resourceStructure configureElements];
}

- (void)loadResource
{
    // create new stream
    ResourceStream *stream = [ResourceStream streamWithData:resource.data];
    // read the data into the template
    [resourceStructure readDataFrom:stream];
	
	// expand all
    [dataList reloadData];
	[dataList expandItem:nil expandChildren:YES];
}

- (BOOL)windowShouldClose:(id)sender
{
	[self.window makeFirstResponder:dataList];
	
	if (self.window.documentEdited) {
		NSAlert *alert = [NSAlert new];
		alert.messageText = @"Do you want to keep the changes you made to this resource?";
		alert.informativeText = @"Your changes cannot be saved later if you don't keep them.";
		[alert addButtonWithTitle:@"Keep"];
		[alert addButtonWithTitle:@"Don't Keep"];
		[alert addButtonWithTitle:@"Cancel"];
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			switch (returnCode) {
				case NSAlertFirstButtonReturn:	// keep
					[self saveResource:nil];
					[self.window close];
					break;
				
				case NSAlertSecondButtonReturn:	// don't keep
					[self.window close];
					break;
				
				case NSModalResponseCancel:		// cancel
					break;
			}
		}];
		return NO;
	}
	return YES;
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
		self.documentEdited = NO;
	}
}

- (void)revertResource:(id)sender
{
	[resource setData:[backup.data copy]];
    [self loadResource];
    self.documentEdited = NO;
}

#pragma mark -
#pragma mark Table Management

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(__kindof Element *)item
{
    if ([tableColumn.identifier isEqualToString:@"data"]) {
        NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, item.rowHeight)];
        [item configureView:view];
        view.toolTip = item.tooltip;
        return view;
    } else if (tableColumn) {
        NSString *identifier = tableColumn.identifier;
        if (item.class == ElementLSTB.class && [item allowsCreateListEntry])
            identifier = @"listLabel";
        NSTableCellView *view = [outlineView makeViewWithIdentifier:identifier owner:self];
        view.textField.stringValue = item.displayLabel;
        view.toolTip = item.tooltip;
        return view;
    } else {
        NSTableCellView *view = [outlineView makeViewWithIdentifier:@"groupView" owner:self];
        [item configureGroupView:view];
        return view;
    }
}

- (id)outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(Element *)item
{
	if (item == nil)
        return [resourceStructure elementAtIndex:index];
	else
        return [item subElementAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(Element *)item
{
    return item.hasSubElements;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(Element *)item
{
	if (item == nil)
		return resourceStructure.count;
	else
        return item.subElementCount;
}

- (double)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(Element *)item
{
    return item.rowHeight;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(Element *)item
{
    return [item respondsToSelector:@selector(configureGroupView:)];
}

#pragma mark -
#pragma mark Menu Management

- (IBAction)itemValueUpdated:(id)sender
{
    if (liveEdit) {
        // remove self to avoid reloading the resource
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ResourceDataDidChangeNotification object:resource];
        [[NSNotificationCenter defaultCenter] postNotificationName:ResourceDataDidChangeNotification object:resource];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:ResourceDataDidChangeNotification object:resource];
    } else {
        self.documentEdited = YES;
    }
}

// these next five methods are a crude hack - the items ought to be in the responder chain themselves
- (IBAction)createListEntry:(id)sender;
{
	// This works by selecting a list element (LSTB) and passing the message on to it
    NSInteger row = [dataList rowForView:(NSView *)self.window.firstResponder];
    id element = [dataList itemAtRow:row];
	if ([element class] == ElementLSTB.class && [element allowsCreateListEntry]) {
        [element createListEntry];
		[dataList reloadData];
        NSView *newHeader = [dataList viewAtColumn:0 row:row makeIfNecessary:YES];
        [self.window makeFirstResponder:newHeader];
        if (!liveEdit) self.documentEdited = YES;
        // Expand the item and scroll the new content into view
		[dataList expandItem:[dataList itemAtRow:row] expandChildren:YES];
        NSView *lastChild = [dataList rowViewAtRow:[dataList rowForItem:element] makeIfNecessary:YES];
        [lastChild scrollRectToVisible:lastChild.bounds];
        [newHeader scrollRectToVisible:newHeader.superview.bounds];
	}
}

- (IBAction)delete:(id)sender;
{
    NSInteger row = [dataList rowForView:(NSView *)self.window.firstResponder];
    id element = [dataList itemAtRow:row];
    if ([element class] == ElementLSTB.class && [element allowsRemoveListEntry]) {
        [element removeListEntry];
        [dataList reloadData];
        [self.window makeFirstResponder:[dataList viewAtColumn:0 row:row makeIfNecessary:YES]];
        if (!liveEdit) self.documentEdited = YES;
    }
}

- (IBAction)cut:(id)sender;
{
}

- (IBAction)copy:(id)sender;
{
}

- (IBAction)paste:(id)sender;
{
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    id element = [dataList itemAtRow:[dataList rowForView:(NSView *)self.window.firstResponder]];
	if (item.action == @selector(createListEntry:))
        return [element class] == ElementLSTB.class && [element allowsCreateListEntry];
	else if (item.action == @selector(delete:))
        return [element class] == ElementLSTB.class && [element allowsRemoveListEntry];
	else if (item.action == @selector(saveResource:) || item.action == @selector(revertResource:))
        return self.window.documentEdited;
	else
        return NO;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemWithTag:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemWithTag:0];
	[createItem setTitle:NSLocalizedString(@"Create List Entry", nil)];
	[createItem setAction:@selector(createListEntry:)];
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	return [resource defaultWindowTitle];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemWithTag:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemWithTag:0];
	[createItem setTitle:NSLocalizedString(@"Create New Resource...", nil)];
	[createItem setAction:@selector(showCreateResourceSheet:)];
}

@end

#pragma mark -
#pragma mark Table Event Handling

// Table views don't support tabbing between rows so we need to handle the key view loop manually
@implementation NTOutlineView

- (void)selectPreviousKeyView:(id)sender
{
    NSView *view = (NSView *)self.window.firstResponder;
    if (view.previousValidKeyView && view.previousValidKeyView != self) {
        [self.window selectPreviousKeyView:view];
        return;
    }
    NSInteger row = [self rowForView:view];
    // Loop through all rows. Break if we come back to where we started without having found anything.
    for (NSInteger i = row-1; i != row; i--) {
        if (i == -1) continue;
        if (i == -2) {
            i = self.numberOfRows;
            continue;
        }
        // Going backward we need to look at the column view and see if it's valid
        view = [self viewAtColumn:1 row:i makeIfNecessary:YES];
        if (![view canBecomeKeyView]) view = [view.subviews lastObject];
        if (![view canBecomeKeyView]) view = [self viewAtColumn:0 row:i makeIfNecessary:YES];
        if ([view canBecomeKeyView]) {
            [self.window makeFirstResponder:view];
            [view scrollRectToVisible:view.superview.bounds];
            return;
        }
    }
}

- (void)selectNextKeyView:(id)sender
{
    NSView *view = (NSView *)self.window.firstResponder;
    if (view.nextValidKeyView) {
        [self.window selectNextKeyView:view];
        return;
    }
    NSInteger row = [self rowForView:view];
    for (NSInteger i = row+1; i != row; i++) {
        if (i == -1) continue;
        if (i == self.numberOfRows) {
            i = -2;
            continue;
        }
        // Going forward we can ask the row for its nextValidKeyView
        view = [self rowViewAtRow:i makeIfNecessary:YES].nextValidKeyView;
        if (view) {
            [self.window makeFirstResponder:view];
            [view scrollRectToVisible:view.superview.bounds];
            return;
        }
    }
}

// Create a little more space for labels by removing the disclosure triangles
- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row
{
    return NSZeroRect;
}

- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row {
    NSRect superFrame = [super frameOfCellAtColumn:column row:row];
    if (column == 0) {
        superFrame.origin.x -= 16;
        superFrame.size.width += 16;
    } else if (column == -1) {
        superFrame.origin.x -= 13;
        superFrame.size.width += 13;
    }
    return superFrame;
}

@end

#pragma mark -
#pragma mark List Header Handling

// This view allows focusing on an LSTB label so we can add/remove list entries
@implementation NTFocusView

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)mouseDown:(NSEvent *)event
{
    [self.window makeFirstResponder:self];
}

- (NSRect)focusRingMaskBounds
{
    return self.textField.frame;
}

- (void)drawFocusRingMask
{
    NSRectFill(self.focusRingMaskBounds);
}

@end
