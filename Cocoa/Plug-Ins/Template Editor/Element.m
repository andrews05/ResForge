#import "Element.h"
#import "ElementCASE.h"
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
	_label = l;
	_type = t;
    self.endType = nil;
    self.visible = YES;
    self.rowHeight = 22;
    self.width = 60; // Default for many types
    self.cases = nil;
    self.caseMap = nil;
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[self.class allocWithZone:zone] initForType:_type withLabel:_label];
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
    if (![self respondsToSelector:@selector(value)]) return;
    NSRect frame = view.frame;
    if (self.width != 0) frame.size.width = self.width-4;
    if (self.cases) {
        frame.size.height = 26;
        frame.origin.y = -2;
        NSComboBox *combo = [[NSComboBox alloc] initWithFrame:frame];
        // Use insensitive completion, except for TNAM
        if (![self.type isEqualToString:@"TNAM"])
            combo.cell = [[NTInsensitiveComboBoxCell alloc] init];
        combo.editable = YES;
        combo.completes = YES;
        combo.numberOfVisibleItems = 10;
        combo.delegate = self;
        combo.placeholderString = self.type;
        [combo bind:@"contentValues" toObject:self withKeyPath:@"cases" options:nil];
        // The formatter isn't directly compatible with the values displayed by the combo box
        // Use a combination of value transformation with immediate validation to run the formatter manually
        [combo bind:@"value" toObject:self withKeyPath:@"value" options:@{NSValueTransformerBindingOption:self,
                                                                              NSValidatesImmediatelyBindingOption:@(self.formatter != nil)}];
        [view addSubview:combo];
    } else {
        NSTextField *textField = [[NSTextField alloc] initWithFrame:frame];
        textField.formatter = self.formatter;
        textField.delegate = self;
        textField.placeholderString = self.type;
        textField.lineBreakMode = NSLineBreakByTruncatingTail;
        textField.allowsDefaultTighteningForTruncation = YES;
        [textField bind:@"value" toObject:self withKeyPath:@"value" options:nil];
        [view addSubview:textField];
    }
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

- (void)configure
{
    // default implementation reads CASE elements
    if (!self.visible) return;
    ElementCASE *element = [self.parentList peek:1];
    while (element.class == ElementCASE.class) {
        [self.parentList pop];
        if (!self.cases) {
            self.cases = [NSMutableArray new];
            self.caseMap = [NSMutableDictionary new];
            self.width = 240;
        }
        // Cases will show as "name = value" in the options list to allow searching by name
        // Text field will display as "value = name" for consistency when there's no matching case
        NSString *option = [NSString stringWithFormat:@"%@ = %@", element.displayLabel, element.value];
        NSString *display = [NSString stringWithFormat:@"%@ = %@", element.value, element.displayLabel];
        [self.cases addObject:option];
        [self.caseMap setObject:display forKey:element.value];
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


// NSComboBoxCell subclass with case-insensitive completion
@implementation NTInsensitiveComboBoxCell

- (NSString *)completedString:(NSString *)string
{
    for (NSString *value in self.objectValues) {
        if ([value commonPrefixWithString:string options:NSCaseInsensitiveSearch].length == string.length) {
            return value;
        }
    }
    return @"";
}

@end
