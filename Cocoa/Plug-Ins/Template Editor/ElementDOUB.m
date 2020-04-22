#import "ElementDOUB.h"

#define SIZE_ON_DISK (8)

@implementation ElementDOUB
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
    CFSwappedFloat64 tmp;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    value = CFConvertDoubleSwappedToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    CFSwappedFloat64 tmp = CFConvertDoubleHostToSwapped(value);
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
