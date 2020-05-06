#import "ElementBORV.h"
#import "ElementCASE.h"
#import "ElementBFLG.h"

#define SIZE_ON_DISK (1)

// BORV is a Rezilla creation which is an OR combination of named (CASE) values
// In Rezilla it is displayed as a multiple select popup menu
// In ResKnife we display it as a list of checkboxes (because we don't have enough checkbox fields already!)
// The main difference from BBITs is it allows a custom ordering of the bits (it also gives a slightly more compact display)
@implementation ElementBORV

- (NSView *)configureView:(NSView *)view
{
    NSRect frame = view.frame;
    frame.size.height = 20;
    frame.origin.y = self.rowHeight-1;
    for (ElementCASE *element in self.cases) {
        frame.origin.y -= 20;
        NSButton *checkbox = [ElementBFLG createCheckboxWithFrame:frame forElement:element];
        checkbox.title = element.displayLabel;
        [view addSubview:checkbox];
    }
    return view;
}

- (void)configure
{
    // Read hex values from the CASEs
    self.cases = [NSMutableArray new];
    self.values = [NSMutableArray new];
    ElementCASE *element = [self.parentList peek:1];
    while (element.class == ElementCASE.class) {
        [self.parentList pop];
        NSString *value = element.value;
        if (value.length && [value characterAtIndex:0] == '$')
            value = [value substringFromIndex:1];
        NSScanner *scanner = [NSScanner scannerWithString:value];
        UInt32 val;
        [scanner scanHexInt:&val];
        [self.cases addObject:element];
        // Store the value in our list while setting the element to 0, which will be used for the checkbox state
        [self.values addObject:@(val)];
        element.value = @"0";
        element = [self.parentList peek:1];
    }
    self.rowHeight = (20 * self.cases.count) + 2;
}

- (void)readDataFrom:(ResourceStream *)stream
{
    UInt8 value;
    [stream readAmount:SIZE_ON_DISK toBuffer:&value];
    for (int i = 0; i < self.cases.count; i++) {
        ElementCASE *element = self.cases[i];
        UInt32 val = [self.values[i] intValue];
        element.value = (value & val) == val ? @"1" : @"0";
    }
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    UInt8 value = 0;
    for (int i = 0; i < self.cases.count; i++) {
        ElementCASE *element = self.cases[i];
        UInt32 val = [self.values[i] intValue];
        if ([element.value boolValue]) value |= val;
    }
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&value];
}

@end
