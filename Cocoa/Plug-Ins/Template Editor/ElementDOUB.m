#import "ElementDOUB.h"

#define SIZE_ON_DISK (8)

@implementation ElementDOUB

- (void)readDataFrom:(ResourceStream *)stream
{
    CFSwappedFloat64 tmp;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    self.value = CFConvertDoubleSwappedToHost(tmp);
}

- (void)sizeOnDisk:(UInt32 *)size
{
    *size += SIZE_ON_DISK;
}

- (void)writeDataTo:(ResourceStream *)stream
{
    CFSwappedFloat64 tmp = CFConvertDoubleHostToSwapped(self.value);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

+ (NSFormatter *)sharedFormatter
{
    static NSNumberFormatter *formatter = nil;
    if (!formatter) {
        formatter = [[NSNumberFormatter alloc] init];
        formatter.hasThousandSeparators = NO;
        formatter.numberStyle = NSNumberFormatterScientificStyle;
        formatter.minimum = 0;
        formatter.maximum = @(DBL_MAX);
        formatter.nilSymbol = @"\0";
    }
    return formatter;
}

@end
