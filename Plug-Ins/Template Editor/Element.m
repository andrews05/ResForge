#import "Element.h"
#import "TemplateWindowController.h"

@implementation Element

+ (id)elementForType:(NSString *)t withLabel:(NSString *)l
{
	return [[self alloc] initForType:t withLabel:l];
}

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
	self = [super init];
	if (!self) return nil;
    // Any extra lines in the label will be used as a tooltip
    NSArray *components = [l componentsSeparatedByString:@"\n"];
    if (components.count > 1) {
        _label = components[0];
        _tooltip = [[components subarrayWithRange:NSMakeRange(1, components.count-1)] componentsJoinedByString:@"\n"];
    } else {
        _label = l;
    }
	_type = t;
    self.visible = YES;
    self.rowHeight = 22;
    self.width = 60; // Default for many types
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	Element *element = [[self.class allocWithZone:zone] initForType:_type withLabel:_label];
    element.tooltip = _tooltip;
    return element;
}

- (NSFormatter *)formatter
{
    return [self.class sharedFormatter];
}

// Notify the controller when a field has been edited
// Use control:textShouldEndEditing: rather than controlTextDidEndEditing: as it more accurately reflects when the value has actually changed
- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor
{
    [(TemplateWindowController *)control.window.windowController itemValueUpdated:control];
    return YES;
}

// Allow tabbing between rows
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    NSOutlineView *outlineView = self.parentList.controller.dataList;
    if (commandSelector == @selector(insertBacktab:) && (!control.previousValidKeyView || control.previousValidKeyView == outlineView)) {
        [outlineView performSelector:@selector(selectPreviousKeyView:) withObject:control];
        return YES;
    } else if (commandSelector == @selector(insertTab:) && !control.nextValidKeyView) {
        [outlineView performSelector:@selector(selectNextKeyView:) withObject:control];
        return YES;
    }
    return NO;
}

- (NSString *)displayLabel
{
    return [[self.label componentsSeparatedByString:@"="] firstObject] ?: @"";
}

#pragma mark -

/*** METHODS SUBCLASSES SHOULD OVERRIDE ***/

- (void)configureView:(NSView *)view
{
    if (![self respondsToSelector:@selector(value)])
        return;
    NSRect frame = view.frame;
    if (self.width != 0) frame.size.width = self.width-4;
    NSTextField *textField = [[NSTextField alloc] initWithFrame:frame];
    textField.formatter = self.formatter;
    textField.delegate = self;
    textField.placeholderString = self.type;
    textField.lineBreakMode = NSLineBreakByTruncatingTail;
    textField.allowsDefaultTighteningForTruncation = YES;
    [textField bind:@"value" toObject:self withKeyPath:@"value" options:nil];
    [view addSubview:textField];
}

+ (NSFormatter *)sharedFormatter
{
    return nil;
}

- (BOOL)hasSubElements
{
    // default implementation suitable for most element types
    return NO;
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

- (void)configure
{
}

// You should read whatever kind of data your template field stands for from "stream"
//	and store it in an instance variable.
- (void)readDataFrom:(ResourceStream *)stream
{
}

// Before writeDataTo:is called, this is called to calculate the final resource size:
//	Items with sub-elements should return the sum of the sizes of all their sub-elements here as well.
- (void)sizeOnDisk:(UInt32 *)size
{
}

- (void)writeDataTo:(ResourceStream *)stream
{
}

@end
