#import "ElementBBIT.h"
#import "ElementBFLG.h"
#import "ElementRECT.h"

#define SIZE_ON_DISK (1)

@implementation ElementBBIT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        self.position = 8;
        if ([t isEqualToString:@"BBIT"]) {
            self.bits = 1;
        } else {
            // BBnn
            self.bits = [[t substringFromIndex:2] intValue];
        }
    }
    return self;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn
{
    if (_bits == 1)
        return [ElementBFLG configureCheckboxForElement:self];
    NSTableCellView *view = [ElementRECT configureFields:@[@"value"] forElement:self];
    view.textField.placeholderString = [NSString stringWithFormat:@"%d bits", _bits];
    view.textField.formatter = [self formatter];
    return view;
}

- (void)readSubElements
{
    self.bitList = [NSMutableArray arrayWithObject:self];
    unsigned int pos = _position -= _bits;
    while (pos > 0) {
        ElementBBIT *element = (ElementBBIT *)[self.parentList peek];
        if (element.class != self.class) {
            NSLog(@"Not enough bits in bit field.");
            break;
        }
        if (element.bits > pos) {
            NSLog(@"'%@' element creates too many bits to complete bit field.", element.type);
            break;
        }
        element.position = pos -= element.bits;
        [self.bitList addObject:element];
        self.parentList.currentIndex++; // Skip this element so it doesn't call readSubElements
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
