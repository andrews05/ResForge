#import "TemplateWindowController.h"
#import "ResourceStream.h"
#import "GroupElement.h"
#import "ElementLSTB.h"

@implementation TemplateWindowController
@synthesize dataList;
@synthesize resource;
@synthesize tmpl;

- (instancetype)initWithResource:(Resource *)newResource
{
	return nil;
}

- (instancetype)initWithResource:(Resource *)newResource template:(Resource *)tmplResource
{
	self = [self initWithWindowNibName:@"TemplateWindow"];
	if (!self) {
		return nil;
	}
	
	//undoManager = [[NSUndoManager alloc] init];
    resource = newResource;
    tmpl = tmplResource;
    resourceStructure = nil;
    [self loadResource];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:@"ResourceDataDidChangeNotification" object:resource];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(templateDataDidChange:) name:@"ResourceDataDidChangeNotification" object:tmpl];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:self.window];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:self.window];
	return self;

}

- (void)windowDidLoad
{
	[super windowDidLoad];
    [self.window setTitle:resource.defaultWindowTitle];
    [dataList expandItem:nil expandChildren:YES];
}

- (void)templateDataDidChange:(NSNotification *)notification
{
    // Reload the template while keeping the current data
    NSData *currentData = [resourceStructure getResourceData];
    [self readTemplate];
    [resourceStructure readResourceData:currentData];
    // expand all
    [dataList reloadData];
    [dataList expandItem:nil expandChildren:YES];
}

- (void)resourceDataDidChange:(NSNotification *)notification
{
    if (!self.window.isDocumentEdited)
        [self loadResource];
}

- (void)readTemplate
{
    NSInputStream *stream = [[NSInputStream alloc] initWithData:tmpl.data];
    resourceStructure = [ElementList listFromStream:stream];
    resourceStructure.controller = self;
    [resourceStructure configureElements];
}

- (void)loadResource
{
    [self readTemplate];
    [resourceStructure readResourceData:resource.data];
	// expand all
    [dataList reloadData];
	[dataList expandItem:nil expandChildren:YES];
    self.documentEdited = NO;
}

- (IBAction)saveResource:(id)sender
{
    // send the new resource data to ResKnife
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ResourceDataDidChangeNotification" object:resource];
    resource.data = [resourceStructure getResourceData];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resourceDataDidChange:) name:@"ResourceDataDidChangeNotification" object:resource];
    self.documentEdited = NO;
}

- (IBAction)revertResource:(id)sender
{
    [self loadResource];
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
    return [item conformsToProtocol:@protocol(GroupElement)];
}

#pragma mark -
#pragma mark Menu Management

- (IBAction)itemValueUpdated:(id)sender
{
    self.documentEdited = YES;
}

// these next five methods are a crude hack - the items ought to be in the responder chain themselves
- (IBAction)createNewItem:(id)sender;
{
	// This works by selecting a list element (LSTB) and passing the message on to it
    NSInteger row = [dataList rowForView:(NSView *)self.window.firstResponder];
    id element = [dataList itemAtRow:row];
	if ([element class] == ElementLSTB.class && [element allowsCreateListEntry]) {
        [element createListEntry];
		[dataList reloadData];
        NSView *newHeader = [dataList viewAtColumn:0 row:row makeIfNecessary:YES];
        [self.window makeFirstResponder:newHeader];
        self.documentEdited = YES;
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
        self.documentEdited = YES;
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
	if (item.action == @selector(createNewItem:))
        return [element class] == ElementLSTB.class && [element allowsCreateListEntry];
	else if (item.action == @selector(delete:))
        return [element class] == ElementLSTB.class && [element allowsRemoveListEntry];
	else if (item.action == @selector(saveResource:) || item.action == @selector(revertResource:))
        return self.window.documentEdited;
	else
        return NO;
}

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
    return resource.defaultWindowTitle;
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemWithTag:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemWithTag:0];
	[createItem setTitle:NSLocalizedString(@"Create List Entry", nil)];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	NSMenu *resourceMenu = [[[NSApp mainMenu] itemWithTag:3] submenu];
	NSMenuItem *createItem = [resourceMenu itemWithTag:0];
	[createItem setTitle:NSLocalizedString(@"Create New Resource…", nil)];
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
