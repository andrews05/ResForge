#import "Element.h"
#import "ElementCASE.h"
#import "TemplateWindowController.h"

@implementation Element
@synthesize type;
@synthesize label;

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
    self.endType = nil;
    self.rowHeight = 17;
    self.visible = YES;
    self.editable = self.class != Element.class;
    self.cases = nil;
    self.caseMap = nil;
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[self.class allocWithZone:zone] initForType:type withLabel:label];
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
    BOOL singleView = control.superview.class == NSTableRowView.class;
    // Move to the next/previous editable row if this is last/first control for this row
    if (commandSelector == @selector(insertTab:) && (singleView || [control.superview.subviews lastObject] == control)) {
        NSInteger nextRow = [outlineView rowForItem:self] + 1;
        while (nextRow < outlineView.numberOfRows && ![[outlineView itemAtRow:nextRow] editable]) {
            nextRow++;
        }
        if (nextRow < outlineView.numberOfRows) {
            [outlineView editColumn:1 row:nextRow withEvent:nil select:NO];
            return YES;
        }
    } else if (commandSelector == @selector(insertBacktab:) && (singleView || [control.superview.subviews firstObject] == control)) {
        NSInteger nextRow = [outlineView rowForItem:self] - 1;
        while (nextRow >= 0 && ![[outlineView itemAtRow:nextRow] editable]) {
            nextRow--;
        }
        if (nextRow >= 0) {
            NSView *view = [outlineView viewAtColumn:1 row:nextRow makeIfNecessary:NO];
            // If there are multiple subviews for this element's view, make sure we edit the last one rather than the first
            if (view.subviews.count > 1) {
                [[view.subviews lastObject] becomeFirstResponder];
            } else {
                [outlineView editColumn:1 row:nextRow withEvent:nil select:NO];
            }
            return YES;
        }
    }
    return NO;
}

#pragma mark -

/*** METHODS SUBCLASSES SHOULD OVERRIDE ***/

- (NSView *)dataView:(NSOutlineView *)outlineView
{
    if (![self respondsToSelector:@selector(value)])
        return nil;
    NSTextField *textField = [outlineView makeViewWithIdentifier:(self.cases ? @"comboData" : @"textData") owner:self];
    textField.editable = self.editable;
    textField.delegate = self;
    textField.placeholderString = self.type;
    if (self.cases) {
        [textField bind:@"contentValues" toObject:self withKeyPath:@"cases" options:nil];
        // The formatter isn't directly compatible with the values displayed by the combo box
        // Use a combination of value transformation with immediate validation to run the formatter manually
        [textField bind:@"value" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self,
                                                                              NSValidatesImmediatelyBindingOption:@(self.formatter != nil)}];
    } else {
        textField.formatter = self.formatter;
        [textField bind:@"value" toObject:self withKeyPath:@"value" options:nil];
    }
    return textField;
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
    // default implementation reads CASE elements
    if (!self.visible || !self.editable) return;
    __kindof Element *element = [self.parentList peek:1];
    while (element.class == ElementCASE.class) {
        [self.parentList pop];
        if (!self.cases) {
            self.cases = [NSMutableArray new];
            self.caseMap = [NSMutableDictionary new];
        }
        // Cases will show as "name = value" in the options list to allow searching by name
        // Text field will display as "value = name" for consistency when there's no matching case
        NSString *option = [NSString stringWithFormat:@"%@ = %@", [element symbol], [element value]];
        NSString *display = [NSString stringWithFormat:@"%@ = %@", [element value], [element symbol]];
        [self.cases addObject:option];
        [self.caseMap setObject:display forKey:[element value]];
        element = [self.parentList peek:1];
    }
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

#pragma mark -
#pragma mark CASE Handling

- (id)transformedValue:(id)value
{
    // Run the value through the formatter before looking it up in the map
    if (self.formatter)
        value = [self.formatter stringForObjectValue:value];
    return [self.caseMap objectForKey:value] ?: value;
}

- (id)reverseTransformedValue:(id)value
{
    // Don't use the formatter here as we can't handle the error
    return [[value componentsSeparatedByString:@" = "] lastObject] ?: value ?: @"";
}

- (BOOL)validateValue:(id *)value error:(NSError **)error
{
    // Here we validate the value with the formatter and can raise an error
    NSString *errorString = nil;
    [self.formatter getObjectValue:value forString:*value errorDescription:&errorString];
    if (errorString) {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSKeyValueValidationError
                                 userInfo:@{NSLocalizedDescriptionKey:errorString}];
        return NO;
    }
    return YES;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification
{
    // Notify the controller that the value changed
    NSControl *control = notification.object;
    [(TemplateWindowController *)control.window.windowController itemValueUpdated:control];
}

@end
