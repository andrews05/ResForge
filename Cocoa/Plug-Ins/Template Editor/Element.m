#import "Element.h"
#import "TemplateWindowController.h"

@implementation Element
@synthesize type;
@synthesize label;
@synthesize parentList;
@synthesize rowHeight;
@synthesize visible;
@synthesize editable;

+ (id)elementForType:(NSString *)t withLabel:(NSString *)l
{
	return [[self alloc] initForType:t withLabel:l];
}

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super init];
	if (!self) return nil;
	label = [l copy];
	type = [t copy];
    rowHeight = 17;
    visible = YES;
    editable = self.class != Element.class;
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	Element *element = [[self.class allocWithZone:zone] initForType:type withLabel:label];
    if (!element) return nil;
	return element;
}

- (NSFormatter *)formatter
{
    return [self.class sharedFormatter];
}

// Notify the controller when a field has been edited
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    [(TemplateWindowController *)[control.window windowController] itemValueUpdated:control];
    return YES;
}

#pragma mark -

/*** METHODS SUBCLASSES SHOULD OVERRIDE ***/

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    if (![self respondsToSelector:@selector(value)])
        return nil;
    NSTableCellView *view = [outlineView makeViewWithIdentifier:tableColumn.identifier owner:self];
    view.textField.editable = self.editable;
    view.textField.delegate = self;
    view.textField.placeholderString = type;
    view.textField.formatter = [self formatter];
    [view.textField bind:@"value" toObject:self withKeyPath:@"value" options:nil];
    return view;
}

+ (NSFormatter *)sharedFormatter
{
    return nil;
}

- (NSInteger)subElementCount
{
	// default implementation suitable for most element types
	return 0;
}

- (Element *)subElementAtIndex:(NSInteger)n
{
	// default implementation suitable for most element types
	return nil;
}

- (void)readSubElements
{
	// by default, items don't read any sub-elements.
}

// You should read whatever kind of data your template field stands for from "stream"
//	and store it in an instance variable.
- (void)readDataFrom:(ResourceStream *)stream
{
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	Items with sub-elements should return the sum of the sizes of all their sub-elements here as well.
- (UInt32)sizeOnDisk:(UInt32)currentSize
{
	// default implementation suitable for dimentionless element types
	return 0;
}

- (void)writeDataTo:(ResourceStream *)stream
{
}

@end
