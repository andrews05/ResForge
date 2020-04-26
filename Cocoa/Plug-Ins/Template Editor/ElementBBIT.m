#import "ElementBBIT.h"
#import "ElementBFLG.h"
#import "ElementRECT.h"

#define SIZE_ON_DISK (1)

@implementation ElementBBIT

- (instancetype)initForType:(NSString *)t withLabel:(NSString *)l
{
    if (self = [super initForType:t withLabel:l]) {
        _position = 8;
        if ([t isEqualToString:@"BBIT"]) {
            _bits = 1;
        } else {
            // BBnn
            _bits = (UInt8)[[t substringFromIndex:2] intValue];
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

- (void)readDataFrom:(ResourceStream *)stream
{
    if (!self.bitList) return;
    [stream readAmount:SIZE_ON_DISK toBuffer:&_completeValue];
    for (ElementBBIT* element in self.bitList) {
        element.value = (_completeValue >> element.position) & ((1 << element.bits) - 1);
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
    _completeValue = 0;
    for (ElementBBIT* element in self.bitList) {
        _completeValue |= element.value << element.position;
    }
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&_completeValue];
}

- (void)readSubElements
{
    if (_position != 8) return;
    self.bitList = [NSMutableArray arrayWithObject:self];
    NSUInteger index = self.parentList.currentIndex+1;
    UInt8 pos = _position -= _bits;
    while (pos > 0) {
        ElementBBIT *element = (ElementBBIT *)[self.parentList elementAtIndex:index++];
        if (element.class != self.class) {
            NSLog(@"Not enough BBITs found to complete a byte.");
            return;
        }
        element.position = pos -= element.bits;
        [self.bitList addObject:element];
    }
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
