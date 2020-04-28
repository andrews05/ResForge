#import "ElementBBIT.h"
#import "ElementBFLG.h"
#import "ElementRECT.h"

#define SIZE_ON_DISK (1)

@implementation ElementBBIT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.compact = YES;
        self.position = 8;
        if ([t isEqualToString:@"BBIT"]) {
            self.bits = 1;
        } else {
            // BBnn
            self.bits = [[t substringFromIndex:2] intValue];
            self.visible = [t characterAtIndex:1] != 'F'; // Hide fill bits
        }
    }
    return self;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    if (self.compact) {
        // Render multiple checkboxes in one row
        NSRect frame = NSMakeRect(0, 0, 240, 18);
        NSView *view = [[NSView alloc] initWithFrame:frame];
        for (ElementBBIT *element in self.bitList) {
            if ([element.type characterAtIndex:1] == 'F') continue; // Skip fill bits (self.visible may not work here)
            NSButton *subview = [ElementBFLG configureCheckboxForElement:element offset:frame.origin.x];
            [view addSubview:subview];
            frame.origin.x += 30;
        }
        return view;
    } else if (_bits == 1) {
        return [ElementBFLG configureCheckboxForElement:self];
    } else {
        NSTableCellView *view = [ElementRECT configureFields:@[@"value"] forElement:self];
        view.textField.placeholderString = [NSString stringWithFormat:@"%d bits", _bits];
        view.textField.formatter = [self formatter];
        return view;
    }
}

- (void)readSubElements
{
    if (!self.compact) return; // While parsing, compact will indicate the first element in the bit field
    self.bitList = [NSMutableArray arrayWithObject:self];
    // If all elements in a bit field have the same label and are either single bits or fillers, compact the checkboxes into one row
    self.compact = self.bits == 1 || !self.visible;
    BOOL hasVisible = self.visible;
    unsigned int pos = _position -= _bits;
    ElementBBIT *element;
    while (pos > 0) {
        element = (ElementBBIT *)[self.parentList peek:self.bitList.count];
        if (element.class != self.class) {
            NSLog(@"Not enough bits in bit field.");
            break;
        }
        if (element.bits > pos) {
            NSLog(@"'%@' element creates too many bits to complete bit field.", element.type);
            break;
        }
        element.position = pos -= element.bits;
        element.compact = NO;
        [self.bitList addObject:element];
        if (![element.label isEqualToString:self.label] || (element.bits != 1 && element.visible))
            self.compact = NO;
        if (element.visible)
            hasVisible = YES;
    }
    if (self.compact && hasVisible) {
        self.visible = YES; // This element is the main row so it must be visible even if it's a filler
        // Remove the others from the list
        for (int i = 1; i < self.bitList.count; i++) {
            [self.parentList pop];
        }
    }
}

- (void)readDataFrom:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt8 completeValue = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&completeValue];
    for (ElementBBIT* element in self.bitList) {
        element.value = (completeValue >> element.position) & ((1 << element.bits) - 1);
    }
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    if (!self.bitList) return 0;
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    if (!self.bitList) return;
    UInt8 completeValue = 0;
    for (ElementBBIT* element in self.bitList) {
        completeValue |= element.value << element.position;
    }
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&completeValue];
}

- (NSFormatter *)formatter
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.hasThousandSeparators = NO;
    formatter.minimum = 0;
    formatter.maximum = @((1 << _bits) - 1);
    formatter.nilSymbol = @"\0";
    return formatter;
}

@end
