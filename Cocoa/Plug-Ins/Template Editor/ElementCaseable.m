#import "ElementCaseable.h"
#import "ElementCASE.h"
#import "TemplateWindowController.h"

// Abstract Element subclass that handles CASE elements
@implementation ElementCaseable

- (void)configureView:(NSView *)view
{
    if (!self.caseMap) {
        [super configureView:view];
        return;
    }
    NSRect frame = view.frame;
    if (self.width != 0) frame.size.width = self.width-1;
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
}

- (void)configure
{
    // Read CASE elements
    ElementCASE *element = [self.parentList peek:1];
    if (element.class == ElementCASE.class) {
        self.cases = [NSMutableArray new];
        self.caseMap = [NSMutableDictionary new];
        self.width = 240;
        while (element.class == ElementCASE.class) {
            [self.parentList pop];
            // Cases will show as "name = value" in the options list to allow searching by name
            // Text field will display as "value = name" for consistency when there's no matching case
            NSString *option = [NSString stringWithFormat:@"%@ = %@", element.displayLabel, element.value];
            NSString *display = [NSString stringWithFormat:@"%@ = %@", element.value, element.displayLabel];
            [self.cases addObject:option];
            [self.caseMap setObject:display forKey:element.value];
            element = [self.parentList peek:1];
        }
    }
}

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
    [self.parentList.controller itemValueUpdated:notification.object];
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

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:NSComboBoxSelectionDidChangeNotification object:self.controlView];
}

// Right margin is set by RSID to allow space for link button
- (NSRect)drawingRectForBounds:(NSRect)rect
{
    rect = [super drawingRectForBounds:rect];
    rect.size.width -= self.rightMargin;
    return rect;
}

@end
